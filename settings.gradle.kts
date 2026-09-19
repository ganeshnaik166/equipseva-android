pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // No extra repositories without a `content {}` filter: an unfiltered
        // maven() is searched for every coordinate the two above do not
        // serve, so a typo'd or unpublished coordinate can be satisfied by
        // whoever controls that host. Every dependency in the catalog is a
        // Central or Google release.
    }
}

rootProject.name = "EquipSeva"
include(":app")
