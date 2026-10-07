package com.equipseva.app.i18n

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Node
import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Owner decision, 23 September 2026: application resources are English only.
 * Reconciles the three source guards from a6e58067 with the current checkout,
 * plus script-content/font guards. This scans source, not merged APK resources.
 * The catalogue floor prevents a missing or unrelated resource tree passing.
 */
class EnglishOnlyResourcesTest {
    @Test
    fun `no locale-qualified values directory exists under res`() {
        // UI modes and other Android qualifiers can be short language-like words.
        val ordinary = listOf(
            "values", "values-night", "values-land", "values-v26", "values-sw600dp",
            "values-tv", "values-car", "values-television", "values-night-land-v26",
            "values-mcc310-mnc004-ldrtl-sw600dp-w820dp-h480dp-large-long-round-" +
                "widecg-highdr-land-car-night-tvdpi-finger-keyshidden-qwerty-navhidden-dpad-v26",
        )
        ordinary.forEach { assertFalse("ordinary qualifier misclassified: $it", isLocaleQualified(it)) }
        val localized = listOf(
            "values-hi", "values-te", "values-en", "values-fil", "values-en-rIN",
            "values-fr-rFR", "values-b+sr+Latn", "values-b+en+US", "values-night-hi",
            "values-v26-zh-rCN", "values-land-b+en+US", "values-night-en-rGB",
            "values-mcc310-te-rIN", "values-night-rIN", "values-night-unknown",
        )
        localized.forEach { assertTrue("locale or unsupported qualifier missed: $it", isLocaleQualified(it)) }

        val resDir = resourceRoot()
        val children = resDir.listFiles() ?: throw AssertionError("Cannot list ${resDir.absolutePath}")
        val translated = children.filter { it.isDirectory && isLocaleQualified(it.name) }
            .map { it.name }.sorted()
        assertTrue(
            "English only: remove locale-qualified or unsupported values directories, found $translated",
            translated.isEmpty(),
        )
    }

    @Test
    fun `default strings file is present and carries the catalog`() {
        // Preserve the original port's >=500 floor rather than an exact key count.
        defaultCatalogue(File(moduleRoot(), "src/main/res"))
    }

    @Test
    fun `build script ships the en locale only`() {
        assertTrue(isEnglishOnlyFilter("androidResources { localeFilters += setOf(\"en\") }"))
        assertTrue(isEnglishOnlyFilter("/* localeFilters += setOf(\"te\") */\n" +
            "androidResources { localeFilters /* nested /* comment */ */ += setOf(\"en\") // hi\n}"))
        assertTrue(isEnglishOnlyFilter("val note = \"localeFilters += setOf(\\\"te\\\")\"\n" +
            "androidResources { localeFilters += setOf(\"en\") }"))
        listOf(
            "// localeFilters += setOf(\"en\")",
            "val note = \"localeFilters += setOf(\\\"en\\\")\"",
            "localeFilters += setOf(\"en\")",
            "androidResources { localeFilters += setOf(\"en\", \"hi\") }",
            "androidResources { localeFilters += setOf(\"en\"); localeFilters += setOf(\"te\") }",
            "androidResources { localeFilters += setOf(\"en\"); localeFilters.add(\"te\") }",
            "androidResources { localeFilters += setOf(\"en\") + setOf(\"te\") }",
            "androidResources { localeFilters += setOf(\"en\")\n + setOf(\"te\") }",
            "androidResources { localeFilters += configuredLocales }",
            "androidResources { localeFilters += setOf(\"en\", \"en\") }",
            "androidResources { localeFilters += setOf(\"en\") /* unclosed",
        ).forEach { assertFalse("unsafe or missing locale filter accepted: $it", isEnglishOnlyFilter(it)) }

        resourceRoot()
        val buildScript = File(moduleRoot(), "build.gradle.kts")
        assertTrue("Missing app build script: ${buildScript.absolutePath}", buildScript.isFile)
        assertTrue(
            "English only: exactly one active localeFilters += setOf(\"en\") is required",
            isEnglishOnlyFilter(readUtf8(buildScript)),
        )
    }

    @Test
    fun `no Devanagari or Telugu code points in any res xml`() {
        val resDir = resourceRoot()
        val files = sourceFiles(resDir).filter { it.extension.equals("xml", ignoreCase = true) }
        assertTrue("No resource XML found under ${resDir.absolutePath}", files.isNotEmpty())
        val violations = files.filter { file ->
            // Raw text also includes comments; DOM catches numeric character references.
            val raw = readUtf8(file)
            hasNativeScript(raw) || nodeHasNativeScript(secureXml().parse(file))
        }.map { it.relativeTo(resDir).invariantSeparatorsPath }
        assertTrue("English only: native script in resource XML: $violations", violations.isEmpty())
    }

    @Test
    fun `no Devanagari or Telugu font files under res font`() {
        val resDir = resourceRoot()
        val fontDir = File(resDir, "font")
        assertTrue("Missing source font directory: ${fontDir.absolutePath}", fontDir.isDirectory)
        val fontRoots = (resDir.listFiles() ?: throw AssertionError("Cannot list $resDir"))
            .filter { it.isDirectory && (it.name == "font" || it.name.startsWith("font-")) }
        val fonts = fontRoots.flatMap(::sourceFiles)
        assertTrue("No source font files found under ${fontDir.absolutePath}", fonts.isNotEmpty())
        val forbidden = Regex("devanagari|telugu", RegexOption.IGNORE_CASE)
        val violations = fonts.filter { forbidden.containsMatchIn(it.name) }
            .map { it.relativeTo(resDir).invariantSeparatorsPath }.sorted()
        assertTrue("English only: remove script-named font files: $violations", violations.isEmpty())
    }

    private fun moduleRoot(): File {
        val candidates = listOf(File("app"), File("."), File("../app"))
            .map { it.canonicalFile }.distinct()
            .filter { it.name == "app" && it.isDirectory && File(it, "build.gradle.kts").isFile }
        assertEquals("Expected one real app module from the working directory, found $candidates", 1, candidates.size)
        return candidates.single()
    }

    private fun resourceRoot(): File = File(moduleRoot(), "src/main/res").also {
        defaultCatalogue(it)
    }

    private fun defaultCatalogue(resDir: File) {
        assertTrue("Missing source resource directory: ${resDir.absolutePath}", resDir.isDirectory)
        val strings = File(resDir, "values/strings.xml")
        assertTrue("Missing default catalogue: ${strings.absolutePath}", strings.isFile)
        readUtf8(strings) // Strict UTF-8: malformed input must not silently become replacement text.
        val document = secureXml().parse(strings)
        assertEquals("Default catalogue root must be resources", "resources", document.documentElement.tagName)
        val nodes = document.getElementsByTagName("string")
        assertTrue("expected the real string catalog, found only ${nodes.length} strings", nodes.length >= 500)
        val names = (0 until nodes.length).map { nodes.item(it).attributes.getNamedItem("name")?.nodeValue.orEmpty() }
        assertTrue("Default catalogue contains unnamed strings", names.all { it.isNotBlank() })
        assertEquals("Default catalogue contains duplicate string keys", names.size, names.toSet().size)
    }

    private fun sourceFiles(root: File): List<File> {
        assertTrue("Missing source scan directory: ${root.absolutePath}", root.isDirectory)
        return root.walkTopDown().onFail { file, error ->
            throw AssertionError("Cannot scan ${file.absolutePath}", error)
        }.filter { it.isFile }.sortedBy { it.invariantSeparatorsPath }.toList()
    }

    private fun readUtf8(file: File): String = Files.readString(file.toPath(), StandardCharsets.UTF_8)

    private fun secureXml() = DocumentBuilderFactory.newInstance().apply {
        setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)
        setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        setFeature("http://xml.org/sax/features/external-general-entities", false)
        setFeature("http://xml.org/sax/features/external-parameter-entities", false)
        setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false)
        // Android's compile stubs omit the newer JAXP constant fields; the
        // standard property URIs retain the same strict JDK parser controls.
        setAttribute("http://javax.xml.XMLConstants/property/accessExternalDTD", "")
        setAttribute("http://javax.xml.XMLConstants/property/accessExternalSchema", "")
        isXIncludeAware = false
        isExpandEntityReferences = false
    }.newDocumentBuilder()

    private fun hasNativeScript(text: String): Boolean = text.any {
        it.code in 0x0900..0x097f || it.code in 0x0c00..0x0c7f
    }

    private fun nodeHasNativeScript(node: Node): Boolean {
        if (hasNativeScript(node.nodeValue.orEmpty())) return true
        val attributes = node.attributes
        if (attributes != null && (0 until attributes.length).any { nodeHasNativeScript(attributes.item(it)) }) return true
        return (0 until node.childNodes.length).any { nodeHasNativeScript(node.childNodes.item(it)) }
    }

    private fun isLocaleQualified(dirName: String): Boolean {
        if (!dirName.startsWith("values-")) return false
        // Check every token; locale qualifiers must not hide after night/mcc/etc.
        // Unknown qualifiers fail closed instead of being treated as English.
        return dirName.removePrefix("values-").split('-').any { qualifier ->
            qualifier !in NON_LOCALE_QUALIFIERS && !NUMERIC_QUALIFIER.matches(qualifier)
        }
    }

    private data class Token(val text: String, val identifier: Boolean, val line: Int)

    private fun isEnglishOnlyFilter(source: String): Boolean {
        val tokens = kotlinTokens(source) ?: return false
        val references = tokens.indices.filter { tokens[it].identifier && tokens[it].text == "localeFilters" }
        if (references.size != 1) return false
        val start = references.single()
        val scopes = mutableListOf<String?>()
        for (index in 0 until start) {
            when (tokens[index].text) {
                "{" -> scopes += tokens.getOrNull(index - 1)?.takeIf { it.identifier }?.text
                "}" -> if (scopes.isEmpty()) return false else scopes.removeAt(scopes.lastIndex)
            }
        }
        if ("androidResources" !in scopes) return false
        val expected = listOf("localeFilters", "+=", "setOf", "(", "\"en\"", ")")
        if (tokens.drop(start).take(expected.size).map { it.text } != expected) return false
        val end = start + expected.size - 1
        val next = tokens.getOrNull(end + 1) ?: return true
        // Refuse appended/continued expressions, including a continuation on a new line.
        if (next.text in setOf("+", "-", ".", "?", "[", "(", "*", "/", "%", "?:")) return false
        return next.text in setOf("}", ";") || next.line > tokens[end].line
    }

    /** Small source lexer: comments and quoted decoys cannot satisfy the DSL guard. */
    private fun kotlinTokens(source: String): List<Token>? {
        val tokens = mutableListOf<Token>()
        var offset = 0
        var line = 1
        fun advance() { if (source[offset] == '\n') line++; offset++ }
        while (offset < source.length) {
            if (source[offset].isWhitespace()) { advance(); continue }
            if (source.startsWith("//", offset)) {
                while (offset < source.length && source[offset] != '\n') advance()
                continue
            }
            if (source.startsWith("/*", offset)) {
                offset += 2
                var depth = 1
                while (offset < source.length && depth > 0) {
                    when {
                        source.startsWith("/*", offset) -> { depth++; offset += 2 }
                        source.startsWith("*/", offset) -> { depth--; offset += 2 }
                        else -> advance()
                    }
                }
                if (depth != 0) return null
                continue
            }
            val start = offset
            val startLine = line
            val character = source[offset]
            if (character == '"' || character == '\'') {
                val delimiter = if (source.startsWith("\"\"\"", offset)) "\"\"\"" else character.toString()
                offset += delimiter.length
                var closed = false
                while (offset < source.length) {
                    if (source.startsWith(delimiter, offset)) { offset += delimiter.length; closed = true; break }
                    if (delimiter.length == 1 && source[offset] == '\\') {
                        advance()
                        if (offset == source.length) return null
                    }
                    advance()
                }
                if (!closed) return null
                val literal = source.substring(start, offset)
                // A template could execute a hidden filter mutation; it is not a literal filter.
                if (literal.contains("\${") && literal.contains("localeFilters")) return null
                tokens += Token(literal, false, startLine)
            } else if (character.isLetter() || character == '_') {
                while (offset < source.length && (source[offset].isLetterOrDigit() || source[offset] == '_')) advance()
                tokens += Token(source.substring(start, offset), true, startLine)
            } else {
                val pair = source.substring(offset, minOf(offset + 2, source.length))
                if (pair in setOf("+=", "-=", "?:")) offset += 2 else advance()
                tokens += Token(source.substring(start, offset), false, startLine)
            }
        }
        return tokens
    }

    private companion object {
        val NUMERIC_QUALIFIER = Regex("mcc[0-9]{3}|mnc[0-9]{1,3}|(?:sw|w|h)[0-9]+dp|[0-9]+dpi|[0-9]+x[0-9]+|v[0-9]+")
        val NON_LOCALE_QUALIFIERS = setOf(
            "ldltr", "ldrtl", "small", "normal", "large", "xlarge", "long", "notlong",
            "round", "notround", "widecg", "nowidecg", "highdr", "lowdr", "port", "land",
            "car", "desk", "television", "tv", "appliance", "watch", "vrheadset", "night", "notnight",
            "ldpi", "mdpi", "tvdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi", "nodpi", "anydpi",
            "notouch", "finger", "keysexposed", "keyshidden", "keyssoft", "nokeys", "qwerty", "12key",
            "navexposed", "navhidden", "nonav", "dpad", "trackball", "wheel",
        )
    }
}
