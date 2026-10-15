(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const r of document.querySelectorAll('link[rel="modulepreload"]'))i(r);new MutationObserver(r=>{for(const s of r)if(s.type==="childList")for(const o of s.addedNodes)o.tagName==="LINK"&&o.rel==="modulepreload"&&i(o)}).observe(document,{childList:!0,subtree:!0});function t(r){const s={};return r.integrity&&(s.integrity=r.integrity),r.referrerPolicy&&(s.referrerPolicy=r.referrerPolicy),r.crossOrigin==="use-credentials"?s.credentials="include":r.crossOrigin==="anonymous"?s.credentials="omit":s.credentials="same-origin",s}function i(r){if(r.ep)return;r.ep=!0;const s=t(r);fetch(r.href,s)}})();/**
 * @license
 * Copyright 2010-2024 Three.js Authors
 * SPDX-License-Identifier: MIT
 */const ua="169",Im=0,bf=1,Um=2,R0=1,Nm=2,Di=3,zi=0,Kt=1,Tn=2,An=0,Ws=1,Zr=2,wf=3,Ef=4,Fm=5,zr=100,Om=101,km=102,Bm=103,zm=104,Hm=200,Gm=201,Vm=202,Wm=203,fu=204,du=205,Xm=206,qm=207,$m=208,Ym=209,Km=210,jm=211,Zm=212,Jm=213,Qm=214,pu=0,mu=1,gu=2,Js=3,vu=4,_u=5,xu=6,yu=7,P0=0,eg=1,tg=2,ki=0,ng=1,ig=2,rg=3,sg=4,og=5,ag=6,lg=7,L0=300,Qs=301,eo=302,Su=303,Mu=304,Gl=306,xl=1e3,Vr=1001,bu=1002,dn=1003,cg=1004,va=1005,hn=1006,ic=1007,lr=1008,on=1009,D0=1010,I0=1011,jo=1012,Ah=1013,xr=1014,_i=1015,ho=1016,Ch=1017,Rh=1018,Jr=1020,U0=35902,N0=1021,F0=1022,Hn=1023,O0=1024,k0=1025,Xs=1026,Qr=1027,B0=1028,Ph=1029,z0=1030,Lh=1031,Dh=1033,sl=33776,ol=33777,al=33778,ll=33779,wu=35840,Eu=35841,Tu=35842,Au=35843,Cu=36196,Ru=37492,Pu=37496,Lu=37808,Du=37809,Iu=37810,Uu=37811,Nu=37812,Fu=37813,Ou=37814,ku=37815,Bu=37816,zu=37817,Hu=37818,Gu=37819,Vu=37820,Wu=37821,cl=36492,Xu=36494,qu=36495,H0=36283,$u=36284,Yu=36285,Ku=36286,ha=3200,ug=3201,hg=0,fg=1,oi="",wt="srgb",wi="srgb-linear",Ih="display-p3",Vl="display-p3-linear",yl="linear",Pt="srgb",Sl="rec709",Ml="p3",fs=7680,Tf=519,dg=512,pg=513,mg=514,G0=515,gg=516,vg=517,_g=518,xg=519,Af=35044,Cf="300 es",Oi=2e3,bl=2001;class Wi{addEventListener(e,t){this._listeners===void 0&&(this._listeners={});const i=this._listeners;i[e]===void 0&&(i[e]=[]),i[e].indexOf(t)===-1&&i[e].push(t)}hasEventListener(e,t){if(this._listeners===void 0)return!1;const i=this._listeners;return i[e]!==void 0&&i[e].indexOf(t)!==-1}removeEventListener(e,t){if(this._listeners===void 0)return;const r=this._listeners[e];if(r!==void 0){const s=r.indexOf(t);s!==-1&&r.splice(s,1)}}dispatchEvent(e){if(this._listeners===void 0)return;const i=this._listeners[e.type];if(i!==void 0){e.target=this;const r=i.slice(0);for(let s=0,o=r.length;s<o;s++)r[s].call(this,e);e.target=null}}}const ln=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];let Rf=1234567;const qs=Math.PI/180,Zo=180/Math.PI;function ss(){const n=Math.random()*4294967295|0,e=Math.random()*4294967295|0,t=Math.random()*4294967295|0,i=Math.random()*4294967295|0;return(ln[n&255]+ln[n>>8&255]+ln[n>>16&255]+ln[n>>24&255]+"-"+ln[e&255]+ln[e>>8&255]+"-"+ln[e>>16&15|64]+ln[e>>24&255]+"-"+ln[t&63|128]+ln[t>>8&255]+"-"+ln[t>>16&255]+ln[t>>24&255]+ln[i&255]+ln[i>>8&255]+ln[i>>16&255]+ln[i>>24&255]).toLowerCase()}function tn(n,e,t){return Math.max(e,Math.min(t,n))}function Uh(n,e){return(n%e+e)%e}function yg(n,e,t,i,r){return i+(n-e)*(r-i)/(t-e)}function Sg(n,e,t){return n!==e?(t-n)/(e-n):0}function zo(n,e,t){return(1-t)*n+t*e}function Mg(n,e,t,i){return zo(n,e,1-Math.exp(-t*i))}function bg(n,e=1){return e-Math.abs(Uh(n,e*2)-e)}function wg(n,e,t){return n<=e?0:n>=t?1:(n=(n-e)/(t-e),n*n*(3-2*n))}function Eg(n,e,t){return n<=e?0:n>=t?1:(n=(n-e)/(t-e),n*n*n*(n*(n*6-15)+10))}function Tg(n,e){return n+Math.floor(Math.random()*(e-n+1))}function Ag(n,e){return n+Math.random()*(e-n)}function Cg(n){return n*(.5-Math.random())}function Rg(n){n!==void 0&&(Rf=n);let e=Rf+=1831565813;return e=Math.imul(e^e>>>15,e|1),e^=e+Math.imul(e^e>>>7,e|61),((e^e>>>14)>>>0)/4294967296}function Pg(n){return n*qs}function Lg(n){return n*Zo}function Dg(n){return(n&n-1)===0&&n!==0}function Ig(n){return Math.pow(2,Math.ceil(Math.log(n)/Math.LN2))}function Ug(n){return Math.pow(2,Math.floor(Math.log(n)/Math.LN2))}function Ng(n,e,t,i,r){const s=Math.cos,o=Math.sin,a=s(t/2),l=o(t/2),c=s((e+i)/2),u=o((e+i)/2),h=s((e-i)/2),f=o((e-i)/2),d=s((i-e)/2),v=o((i-e)/2);switch(r){case"XYX":n.set(a*u,l*h,l*f,a*c);break;case"YZY":n.set(l*f,a*u,l*h,a*c);break;case"ZXZ":n.set(l*h,l*f,a*u,a*c);break;case"XZX":n.set(a*u,l*v,l*d,a*c);break;case"YXY":n.set(l*d,a*u,l*v,a*c);break;case"ZYZ":n.set(l*v,l*d,a*u,a*c);break;default:console.warn("THREE.MathUtils: .setQuaternionFromProperEuler() encountered an unknown order: "+r)}}function Us(n,e){switch(e.constructor){case Float32Array:return n;case Uint32Array:return n/4294967295;case Uint16Array:return n/65535;case Uint8Array:return n/255;case Int32Array:return Math.max(n/2147483647,-1);case Int16Array:return Math.max(n/32767,-1);case Int8Array:return Math.max(n/127,-1);default:throw new Error("Invalid component type.")}}function vn(n,e){switch(e.constructor){case Float32Array:return n;case Uint32Array:return Math.round(n*4294967295);case Uint16Array:return Math.round(n*65535);case Uint8Array:return Math.round(n*255);case Int32Array:return Math.round(n*2147483647);case Int16Array:return Math.round(n*32767);case Int8Array:return Math.round(n*127);default:throw new Error("Invalid component type.")}}const Bi={DEG2RAD:qs,RAD2DEG:Zo,generateUUID:ss,clamp:tn,euclideanModulo:Uh,mapLinear:yg,inverseLerp:Sg,lerp:zo,damp:Mg,pingpong:bg,smoothstep:wg,smootherstep:Eg,randInt:Tg,randFloat:Ag,randFloatSpread:Cg,seededRandom:Rg,degToRad:Pg,radToDeg:Lg,isPowerOfTwo:Dg,ceilPowerOfTwo:Ig,floorPowerOfTwo:Ug,setQuaternionFromProperEuler:Ng,normalize:vn,denormalize:Us};class we{constructor(e=0,t=0){we.prototype.isVector2=!0,this.x=e,this.y=t}get width(){return this.x}set width(e){this.x=e}get height(){return this.y}set height(e){this.y=e}set(e,t){return this.x=e,this.y=t,this}setScalar(e){return this.x=e,this.y=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y)}copy(e){return this.x=e.x,this.y=e.y,this}add(e){return this.x+=e.x,this.y+=e.y,this}addScalar(e){return this.x+=e,this.y+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this}subScalar(e){return this.x-=e,this.y-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this}multiply(e){return this.x*=e.x,this.y*=e.y,this}multiplyScalar(e){return this.x*=e,this.y*=e,this}divide(e){return this.x/=e.x,this.y/=e.y,this}divideScalar(e){return this.multiplyScalar(1/e)}applyMatrix3(e){const t=this.x,i=this.y,r=e.elements;return this.x=r[0]*t+r[3]*i+r[6],this.y=r[1]*t+r[4]*i+r[7],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this}clampLength(e,t){const i=this.length();return this.divideScalar(i||1).multiplyScalar(Math.max(e,Math.min(t,i)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(e){return this.x*e.x+this.y*e.y}cross(e){return this.x*e.y-this.y*e.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(e){const t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;const i=this.dot(e)/t;return Math.acos(tn(i,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){const t=this.x-e.x,i=this.y-e.y;return t*t+i*i}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this}lerpVectors(e,t,i){return this.x=e.x+(t.x-e.x)*i,this.y=e.y+(t.y-e.y)*i,this}equals(e){return e.x===this.x&&e.y===this.y}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this}rotateAround(e,t){const i=Math.cos(t),r=Math.sin(t),s=this.x-e.x,o=this.y-e.y;return this.x=s*i-o*r+e.x,this.y=s*r+o*i+e.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}}class tt{constructor(e,t,i,r,s,o,a,l,c){tt.prototype.isMatrix3=!0,this.elements=[1,0,0,0,1,0,0,0,1],e!==void 0&&this.set(e,t,i,r,s,o,a,l,c)}set(e,t,i,r,s,o,a,l,c){const u=this.elements;return u[0]=e,u[1]=r,u[2]=a,u[3]=t,u[4]=s,u[5]=l,u[6]=i,u[7]=o,u[8]=c,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(e){const t=this.elements,i=e.elements;return t[0]=i[0],t[1]=i[1],t[2]=i[2],t[3]=i[3],t[4]=i[4],t[5]=i[5],t[6]=i[6],t[7]=i[7],t[8]=i[8],this}extractBasis(e,t,i){return e.setFromMatrix3Column(this,0),t.setFromMatrix3Column(this,1),i.setFromMatrix3Column(this,2),this}setFromMatrix4(e){const t=e.elements;return this.set(t[0],t[4],t[8],t[1],t[5],t[9],t[2],t[6],t[10]),this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){const i=e.elements,r=t.elements,s=this.elements,o=i[0],a=i[3],l=i[6],c=i[1],u=i[4],h=i[7],f=i[2],d=i[5],v=i[8],g=r[0],p=r[3],m=r[6],x=r[1],_=r[4],y=r[7],C=r[2],M=r[5],w=r[8];return s[0]=o*g+a*x+l*C,s[3]=o*p+a*_+l*M,s[6]=o*m+a*y+l*w,s[1]=c*g+u*x+h*C,s[4]=c*p+u*_+h*M,s[7]=c*m+u*y+h*w,s[2]=f*g+d*x+v*C,s[5]=f*p+d*_+v*M,s[8]=f*m+d*y+v*w,this}multiplyScalar(e){const t=this.elements;return t[0]*=e,t[3]*=e,t[6]*=e,t[1]*=e,t[4]*=e,t[7]*=e,t[2]*=e,t[5]*=e,t[8]*=e,this}determinant(){const e=this.elements,t=e[0],i=e[1],r=e[2],s=e[3],o=e[4],a=e[5],l=e[6],c=e[7],u=e[8];return t*o*u-t*a*c-i*s*u+i*a*l+r*s*c-r*o*l}invert(){const e=this.elements,t=e[0],i=e[1],r=e[2],s=e[3],o=e[4],a=e[5],l=e[6],c=e[7],u=e[8],h=u*o-a*c,f=a*l-u*s,d=c*s-o*l,v=t*h+i*f+r*d;if(v===0)return this.set(0,0,0,0,0,0,0,0,0);const g=1/v;return e[0]=h*g,e[1]=(r*c-u*i)*g,e[2]=(a*i-r*o)*g,e[3]=f*g,e[4]=(u*t-r*l)*g,e[5]=(r*s-a*t)*g,e[6]=d*g,e[7]=(i*l-c*t)*g,e[8]=(o*t-i*s)*g,this}transpose(){let e;const t=this.elements;return e=t[1],t[1]=t[3],t[3]=e,e=t[2],t[2]=t[6],t[6]=e,e=t[5],t[5]=t[7],t[7]=e,this}getNormalMatrix(e){return this.setFromMatrix4(e).invert().transpose()}transposeIntoArray(e){const t=this.elements;return e[0]=t[0],e[1]=t[3],e[2]=t[6],e[3]=t[1],e[4]=t[4],e[5]=t[7],e[6]=t[2],e[7]=t[5],e[8]=t[8],this}setUvTransform(e,t,i,r,s,o,a){const l=Math.cos(s),c=Math.sin(s);return this.set(i*l,i*c,-i*(l*o+c*a)+o+e,-r*c,r*l,-r*(-c*o+l*a)+a+t,0,0,1),this}scale(e,t){return this.premultiply(rc.makeScale(e,t)),this}rotate(e){return this.premultiply(rc.makeRotation(-e)),this}translate(e,t){return this.premultiply(rc.makeTranslation(e,t)),this}makeTranslation(e,t){return e.isVector2?this.set(1,0,e.x,0,1,e.y,0,0,1):this.set(1,0,e,0,1,t,0,0,1),this}makeRotation(e){const t=Math.cos(e),i=Math.sin(e);return this.set(t,-i,0,i,t,0,0,0,1),this}makeScale(e,t){return this.set(e,0,0,0,t,0,0,0,1),this}equals(e){const t=this.elements,i=e.elements;for(let r=0;r<9;r++)if(t[r]!==i[r])return!1;return!0}fromArray(e,t=0){for(let i=0;i<9;i++)this.elements[i]=e[i+t];return this}toArray(e=[],t=0){const i=this.elements;return e[t]=i[0],e[t+1]=i[1],e[t+2]=i[2],e[t+3]=i[3],e[t+4]=i[4],e[t+5]=i[5],e[t+6]=i[6],e[t+7]=i[7],e[t+8]=i[8],e}clone(){return new this.constructor().fromArray(this.elements)}}const rc=new tt;function V0(n){for(let e=n.length-1;e>=0;--e)if(n[e]>=65535)return!0;return!1}function wl(n){return document.createElementNS("http://www.w3.org/1999/xhtml",n)}function Fg(){const n=wl("canvas");return n.style.display="block",n}const Pf={};function ul(n){n in Pf||(Pf[n]=!0,console.warn(n))}function Og(n,e,t){return new Promise(function(i,r){function s(){switch(n.clientWaitSync(e,n.SYNC_FLUSH_COMMANDS_BIT,0)){case n.WAIT_FAILED:r();break;case n.TIMEOUT_EXPIRED:setTimeout(s,t);break;default:i()}}setTimeout(s,t)})}function kg(n){const e=n.elements;e[2]=.5*e[2]+.5*e[3],e[6]=.5*e[6]+.5*e[7],e[10]=.5*e[10]+.5*e[11],e[14]=.5*e[14]+.5*e[15]}function Bg(n){const e=n.elements;e[11]===-1?(e[10]=-e[10]-1,e[14]=-e[14]):(e[10]=-e[10],e[14]=-e[14]+1)}const Lf=new tt().set(.8224621,.177538,0,.0331941,.9668058,0,.0170827,.0723974,.9105199),Df=new tt().set(1.2249401,-.2249404,0,-.0420569,1.0420571,0,-.0196376,-.0786361,1.0982735),So={[wi]:{transfer:yl,primaries:Sl,luminanceCoefficients:[.2126,.7152,.0722],toReference:n=>n,fromReference:n=>n},[wt]:{transfer:Pt,primaries:Sl,luminanceCoefficients:[.2126,.7152,.0722],toReference:n=>n.convertSRGBToLinear(),fromReference:n=>n.convertLinearToSRGB()},[Vl]:{transfer:yl,primaries:Ml,luminanceCoefficients:[.2289,.6917,.0793],toReference:n=>n.applyMatrix3(Df),fromReference:n=>n.applyMatrix3(Lf)},[Ih]:{transfer:Pt,primaries:Ml,luminanceCoefficients:[.2289,.6917,.0793],toReference:n=>n.convertSRGBToLinear().applyMatrix3(Df),fromReference:n=>n.applyMatrix3(Lf).convertLinearToSRGB()}},zg=new Set([wi,Vl]),gt={enabled:!0,_workingColorSpace:wi,get workingColorSpace(){return this._workingColorSpace},set workingColorSpace(n){if(!zg.has(n))throw new Error(`Unsupported working color space, "${n}".`);this._workingColorSpace=n},convert:function(n,e,t){if(this.enabled===!1||e===t||!e||!t)return n;const i=So[e].toReference,r=So[t].fromReference;return r(i(n))},fromWorkingColorSpace:function(n,e){return this.convert(n,this._workingColorSpace,e)},toWorkingColorSpace:function(n,e){return this.convert(n,e,this._workingColorSpace)},getPrimaries:function(n){return So[n].primaries},getTransfer:function(n){return n===oi?yl:So[n].transfer},getLuminanceCoefficients:function(n,e=this._workingColorSpace){return n.fromArray(So[e].luminanceCoefficients)}};function $s(n){return n<.04045?n*.0773993808:Math.pow(n*.9478672986+.0521327014,2.4)}function sc(n){return n<.0031308?n*12.92:1.055*Math.pow(n,.41666)-.055}let ds;class Hg{static getDataURL(e){if(/^data:/i.test(e.src)||typeof HTMLCanvasElement>"u")return e.src;let t;if(e instanceof HTMLCanvasElement)t=e;else{ds===void 0&&(ds=wl("canvas")),ds.width=e.width,ds.height=e.height;const i=ds.getContext("2d");e instanceof ImageData?i.putImageData(e,0,0):i.drawImage(e,0,0,e.width,e.height),t=ds}return t.width>2048||t.height>2048?(console.warn("THREE.ImageUtils.getDataURL: Image converted to jpg for performance reasons",e),t.toDataURL("image/jpeg",.6)):t.toDataURL("image/png")}static sRGBToLinear(e){if(typeof HTMLImageElement<"u"&&e instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&e instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&e instanceof ImageBitmap){const t=wl("canvas");t.width=e.width,t.height=e.height;const i=t.getContext("2d");i.drawImage(e,0,0,e.width,e.height);const r=i.getImageData(0,0,e.width,e.height),s=r.data;for(let o=0;o<s.length;o++)s[o]=$s(s[o]/255)*255;return i.putImageData(r,0,0),t}else if(e.data){const t=e.data.slice(0);for(let i=0;i<t.length;i++)t instanceof Uint8Array||t instanceof Uint8ClampedArray?t[i]=Math.floor($s(t[i]/255)*255):t[i]=$s(t[i]);return{data:t,width:e.width,height:e.height}}else return console.warn("THREE.ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),e}}let Gg=0;class W0{constructor(e=null){this.isSource=!0,Object.defineProperty(this,"id",{value:Gg++}),this.uuid=ss(),this.data=e,this.dataReady=!0,this.version=0}set needsUpdate(e){e===!0&&this.version++}toJSON(e){const t=e===void 0||typeof e=="string";if(!t&&e.images[this.uuid]!==void 0)return e.images[this.uuid];const i={uuid:this.uuid,url:""},r=this.data;if(r!==null){let s;if(Array.isArray(r)){s=[];for(let o=0,a=r.length;o<a;o++)r[o].isDataTexture?s.push(oc(r[o].image)):s.push(oc(r[o]))}else s=oc(r);i.url=s}return t||(e.images[this.uuid]=i),i}}function oc(n){return typeof HTMLImageElement<"u"&&n instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&n instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&n instanceof ImageBitmap?Hg.getDataURL(n):n.data?{data:Array.from(n.data),width:n.width,height:n.height,type:n.data.constructor.name}:(console.warn("THREE.Texture: Unable to serialize Texture."),{})}let Vg=0;class sn extends Wi{constructor(e=sn.DEFAULT_IMAGE,t=sn.DEFAULT_MAPPING,i=Vr,r=Vr,s=hn,o=lr,a=Hn,l=on,c=sn.DEFAULT_ANISOTROPY,u=oi){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:Vg++}),this.uuid=ss(),this.name="",this.source=new W0(e),this.mipmaps=[],this.mapping=t,this.channel=0,this.wrapS=i,this.wrapT=r,this.magFilter=s,this.minFilter=o,this.anisotropy=c,this.format=a,this.internalFormat=null,this.type=l,this.offset=new we(0,0),this.repeat=new we(1,1),this.center=new we(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new tt,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=u,this.userData={},this.version=0,this.onUpdate=null,this.isRenderTargetTexture=!1,this.pmremVersion=0}get image(){return this.source.data}set image(e=null){this.source.data=e}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}clone(){return new this.constructor().copy(this)}copy(e){return this.name=e.name,this.source=e.source,this.mipmaps=e.mipmaps.slice(0),this.mapping=e.mapping,this.channel=e.channel,this.wrapS=e.wrapS,this.wrapT=e.wrapT,this.magFilter=e.magFilter,this.minFilter=e.minFilter,this.anisotropy=e.anisotropy,this.format=e.format,this.internalFormat=e.internalFormat,this.type=e.type,this.offset.copy(e.offset),this.repeat.copy(e.repeat),this.center.copy(e.center),this.rotation=e.rotation,this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrix.copy(e.matrix),this.generateMipmaps=e.generateMipmaps,this.premultiplyAlpha=e.premultiplyAlpha,this.flipY=e.flipY,this.unpackAlignment=e.unpackAlignment,this.colorSpace=e.colorSpace,this.userData=JSON.parse(JSON.stringify(e.userData)),this.needsUpdate=!0,this}toJSON(e){const t=e===void 0||typeof e=="string";if(!t&&e.textures[this.uuid]!==void 0)return e.textures[this.uuid];const i={metadata:{version:4.6,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(e).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(i.userData=this.userData),t||(e.textures[this.uuid]=i),i}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(e){if(this.mapping!==L0)return e;if(e.applyMatrix3(this.matrix),e.x<0||e.x>1)switch(this.wrapS){case xl:e.x=e.x-Math.floor(e.x);break;case Vr:e.x=e.x<0?0:1;break;case bu:Math.abs(Math.floor(e.x)%2)===1?e.x=Math.ceil(e.x)-e.x:e.x=e.x-Math.floor(e.x);break}if(e.y<0||e.y>1)switch(this.wrapT){case xl:e.y=e.y-Math.floor(e.y);break;case Vr:e.y=e.y<0?0:1;break;case bu:Math.abs(Math.floor(e.y)%2)===1?e.y=Math.ceil(e.y)-e.y:e.y=e.y-Math.floor(e.y);break}return this.flipY&&(e.y=1-e.y),e}set needsUpdate(e){e===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(e){e===!0&&this.pmremVersion++}}sn.DEFAULT_IMAGE=null;sn.DEFAULT_MAPPING=L0;sn.DEFAULT_ANISOTROPY=1;class Ct{constructor(e=0,t=0,i=0,r=1){Ct.prototype.isVector4=!0,this.x=e,this.y=t,this.z=i,this.w=r}get width(){return this.z}set width(e){this.z=e}get height(){return this.w}set height(e){this.w=e}set(e,t,i,r){return this.x=e,this.y=t,this.z=i,this.w=r,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this.w=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setW(e){return this.w=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;case 3:this.w=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this.w=e.w!==void 0?e.w:1,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this.w+=e.w,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this.w+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this.w=e.w+t.w,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this.w+=e.w*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this.w-=e.w,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this.w-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this.w=e.w-t.w,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this.w*=e.w,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this.w*=e,this}applyMatrix4(e){const t=this.x,i=this.y,r=this.z,s=this.w,o=e.elements;return this.x=o[0]*t+o[4]*i+o[8]*r+o[12]*s,this.y=o[1]*t+o[5]*i+o[9]*r+o[13]*s,this.z=o[2]*t+o[6]*i+o[10]*r+o[14]*s,this.w=o[3]*t+o[7]*i+o[11]*r+o[15]*s,this}divideScalar(e){return this.multiplyScalar(1/e)}setAxisAngleFromQuaternion(e){this.w=2*Math.acos(e.w);const t=Math.sqrt(1-e.w*e.w);return t<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=e.x/t,this.y=e.y/t,this.z=e.z/t),this}setAxisAngleFromRotationMatrix(e){let t,i,r,s;const l=e.elements,c=l[0],u=l[4],h=l[8],f=l[1],d=l[5],v=l[9],g=l[2],p=l[6],m=l[10];if(Math.abs(u-f)<.01&&Math.abs(h-g)<.01&&Math.abs(v-p)<.01){if(Math.abs(u+f)<.1&&Math.abs(h+g)<.1&&Math.abs(v+p)<.1&&Math.abs(c+d+m-3)<.1)return this.set(1,0,0,0),this;t=Math.PI;const _=(c+1)/2,y=(d+1)/2,C=(m+1)/2,M=(u+f)/4,w=(h+g)/4,P=(v+p)/4;return _>y&&_>C?_<.01?(i=0,r=.707106781,s=.707106781):(i=Math.sqrt(_),r=M/i,s=w/i):y>C?y<.01?(i=.707106781,r=0,s=.707106781):(r=Math.sqrt(y),i=M/r,s=P/r):C<.01?(i=.707106781,r=.707106781,s=0):(s=Math.sqrt(C),i=w/s,r=P/s),this.set(i,r,s,t),this}let x=Math.sqrt((p-v)*(p-v)+(h-g)*(h-g)+(f-u)*(f-u));return Math.abs(x)<.001&&(x=1),this.x=(p-v)/x,this.y=(h-g)/x,this.z=(f-u)/x,this.w=Math.acos((c+d+m-1)/2),this}setFromMatrixPosition(e){const t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this.w=t[15],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this.w=Math.min(this.w,e.w),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this.w=Math.max(this.w,e.w),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this.z=Math.max(e.z,Math.min(t.z,this.z)),this.w=Math.max(e.w,Math.min(t.w,this.w)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this.z=Math.max(e,Math.min(t,this.z)),this.w=Math.max(e,Math.min(t,this.w)),this}clampLength(e,t){const i=this.length();return this.divideScalar(i||1).multiplyScalar(Math.max(e,Math.min(t,i)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z+this.w*e.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this.w+=(e.w-this.w)*t,this}lerpVectors(e,t,i){return this.x=e.x+(t.x-e.x)*i,this.y=e.y+(t.y-e.y)*i,this.z=e.z+(t.z-e.z)*i,this.w=e.w+(t.w-e.w)*i,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z&&e.w===this.w}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this.w=e[t+3],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e[t+3]=this.w,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this.w=e.getW(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}}class Wg extends Wi{constructor(e=1,t=1,i={}){super(),this.isRenderTarget=!0,this.width=e,this.height=t,this.depth=1,this.scissor=new Ct(0,0,e,t),this.scissorTest=!1,this.viewport=new Ct(0,0,e,t);const r={width:e,height:t,depth:1};i=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:hn,depthBuffer:!0,stencilBuffer:!1,resolveDepthBuffer:!0,resolveStencilBuffer:!0,depthTexture:null,samples:0,count:1},i);const s=new sn(r,i.mapping,i.wrapS,i.wrapT,i.magFilter,i.minFilter,i.format,i.type,i.anisotropy,i.colorSpace);s.flipY=!1,s.generateMipmaps=i.generateMipmaps,s.internalFormat=i.internalFormat,this.textures=[];const o=i.count;for(let a=0;a<o;a++)this.textures[a]=s.clone(),this.textures[a].isRenderTargetTexture=!0;this.depthBuffer=i.depthBuffer,this.stencilBuffer=i.stencilBuffer,this.resolveDepthBuffer=i.resolveDepthBuffer,this.resolveStencilBuffer=i.resolveStencilBuffer,this.depthTexture=i.depthTexture,this.samples=i.samples}get texture(){return this.textures[0]}set texture(e){this.textures[0]=e}setSize(e,t,i=1){if(this.width!==e||this.height!==t||this.depth!==i){this.width=e,this.height=t,this.depth=i;for(let r=0,s=this.textures.length;r<s;r++)this.textures[r].image.width=e,this.textures[r].image.height=t,this.textures[r].image.depth=i;this.dispose()}this.viewport.set(0,0,e,t),this.scissor.set(0,0,e,t)}clone(){return new this.constructor().copy(this)}copy(e){this.width=e.width,this.height=e.height,this.depth=e.depth,this.scissor.copy(e.scissor),this.scissorTest=e.scissorTest,this.viewport.copy(e.viewport),this.textures.length=0;for(let i=0,r=e.textures.length;i<r;i++)this.textures[i]=e.textures[i].clone(),this.textures[i].isRenderTargetTexture=!0;const t=Object.assign({},e.texture.image);return this.texture.source=new W0(t),this.depthBuffer=e.depthBuffer,this.stencilBuffer=e.stencilBuffer,this.resolveDepthBuffer=e.resolveDepthBuffer,this.resolveStencilBuffer=e.resolveStencilBuffer,e.depthTexture!==null&&(this.depthTexture=e.depthTexture.clone()),this.samples=e.samples,this}dispose(){this.dispatchEvent({type:"dispose"})}}class Sn extends Wg{constructor(e=1,t=1,i={}){super(e,t,i),this.isWebGLRenderTarget=!0}}class El extends sn{constructor(e=null,t=1,i=1,r=1){super(null),this.isDataArrayTexture=!0,this.image={data:e,width:t,height:i,depth:r},this.magFilter=dn,this.minFilter=dn,this.wrapR=Vr,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}addLayerUpdate(e){this.layerUpdates.add(e)}clearLayerUpdates(){this.layerUpdates.clear()}}class Xg extends sn{constructor(e=null,t=1,i=1,r=1){super(null),this.isData3DTexture=!0,this.image={data:e,width:t,height:i,depth:r},this.magFilter=dn,this.minFilter=dn,this.wrapR=Vr,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}}class Hi{constructor(e=0,t=0,i=0,r=1){this.isQuaternion=!0,this._x=e,this._y=t,this._z=i,this._w=r}static slerpFlat(e,t,i,r,s,o,a){let l=i[r+0],c=i[r+1],u=i[r+2],h=i[r+3];const f=s[o+0],d=s[o+1],v=s[o+2],g=s[o+3];if(a===0){e[t+0]=l,e[t+1]=c,e[t+2]=u,e[t+3]=h;return}if(a===1){e[t+0]=f,e[t+1]=d,e[t+2]=v,e[t+3]=g;return}if(h!==g||l!==f||c!==d||u!==v){let p=1-a;const m=l*f+c*d+u*v+h*g,x=m>=0?1:-1,_=1-m*m;if(_>Number.EPSILON){const C=Math.sqrt(_),M=Math.atan2(C,m*x);p=Math.sin(p*M)/C,a=Math.sin(a*M)/C}const y=a*x;if(l=l*p+f*y,c=c*p+d*y,u=u*p+v*y,h=h*p+g*y,p===1-a){const C=1/Math.sqrt(l*l+c*c+u*u+h*h);l*=C,c*=C,u*=C,h*=C}}e[t]=l,e[t+1]=c,e[t+2]=u,e[t+3]=h}static multiplyQuaternionsFlat(e,t,i,r,s,o){const a=i[r],l=i[r+1],c=i[r+2],u=i[r+3],h=s[o],f=s[o+1],d=s[o+2],v=s[o+3];return e[t]=a*v+u*h+l*d-c*f,e[t+1]=l*v+u*f+c*h-a*d,e[t+2]=c*v+u*d+a*f-l*h,e[t+3]=u*v-a*h-l*f-c*d,e}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get w(){return this._w}set w(e){this._w=e,this._onChangeCallback()}set(e,t,i,r){return this._x=e,this._y=t,this._z=i,this._w=r,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(e){return this._x=e.x,this._y=e.y,this._z=e.z,this._w=e.w,this._onChangeCallback(),this}setFromEuler(e,t=!0){const i=e._x,r=e._y,s=e._z,o=e._order,a=Math.cos,l=Math.sin,c=a(i/2),u=a(r/2),h=a(s/2),f=l(i/2),d=l(r/2),v=l(s/2);switch(o){case"XYZ":this._x=f*u*h+c*d*v,this._y=c*d*h-f*u*v,this._z=c*u*v+f*d*h,this._w=c*u*h-f*d*v;break;case"YXZ":this._x=f*u*h+c*d*v,this._y=c*d*h-f*u*v,this._z=c*u*v-f*d*h,this._w=c*u*h+f*d*v;break;case"ZXY":this._x=f*u*h-c*d*v,this._y=c*d*h+f*u*v,this._z=c*u*v+f*d*h,this._w=c*u*h-f*d*v;break;case"ZYX":this._x=f*u*h-c*d*v,this._y=c*d*h+f*u*v,this._z=c*u*v-f*d*h,this._w=c*u*h+f*d*v;break;case"YZX":this._x=f*u*h+c*d*v,this._y=c*d*h+f*u*v,this._z=c*u*v-f*d*h,this._w=c*u*h-f*d*v;break;case"XZY":this._x=f*u*h-c*d*v,this._y=c*d*h-f*u*v,this._z=c*u*v+f*d*h,this._w=c*u*h+f*d*v;break;default:console.warn("THREE.Quaternion: .setFromEuler() encountered an unknown order: "+o)}return t===!0&&this._onChangeCallback(),this}setFromAxisAngle(e,t){const i=t/2,r=Math.sin(i);return this._x=e.x*r,this._y=e.y*r,this._z=e.z*r,this._w=Math.cos(i),this._onChangeCallback(),this}setFromRotationMatrix(e){const t=e.elements,i=t[0],r=t[4],s=t[8],o=t[1],a=t[5],l=t[9],c=t[2],u=t[6],h=t[10],f=i+a+h;if(f>0){const d=.5/Math.sqrt(f+1);this._w=.25/d,this._x=(u-l)*d,this._y=(s-c)*d,this._z=(o-r)*d}else if(i>a&&i>h){const d=2*Math.sqrt(1+i-a-h);this._w=(u-l)/d,this._x=.25*d,this._y=(r+o)/d,this._z=(s+c)/d}else if(a>h){const d=2*Math.sqrt(1+a-i-h);this._w=(s-c)/d,this._x=(r+o)/d,this._y=.25*d,this._z=(l+u)/d}else{const d=2*Math.sqrt(1+h-i-a);this._w=(o-r)/d,this._x=(s+c)/d,this._y=(l+u)/d,this._z=.25*d}return this._onChangeCallback(),this}setFromUnitVectors(e,t){let i=e.dot(t)+1;return i<Number.EPSILON?(i=0,Math.abs(e.x)>Math.abs(e.z)?(this._x=-e.y,this._y=e.x,this._z=0,this._w=i):(this._x=0,this._y=-e.z,this._z=e.y,this._w=i)):(this._x=e.y*t.z-e.z*t.y,this._y=e.z*t.x-e.x*t.z,this._z=e.x*t.y-e.y*t.x,this._w=i),this.normalize()}angleTo(e){return 2*Math.acos(Math.abs(tn(this.dot(e),-1,1)))}rotateTowards(e,t){const i=this.angleTo(e);if(i===0)return this;const r=Math.min(1,t/i);return this.slerp(e,r),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(e){return this._x*e._x+this._y*e._y+this._z*e._z+this._w*e._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let e=this.length();return e===0?(this._x=0,this._y=0,this._z=0,this._w=1):(e=1/e,this._x=this._x*e,this._y=this._y*e,this._z=this._z*e,this._w=this._w*e),this._onChangeCallback(),this}multiply(e){return this.multiplyQuaternions(this,e)}premultiply(e){return this.multiplyQuaternions(e,this)}multiplyQuaternions(e,t){const i=e._x,r=e._y,s=e._z,o=e._w,a=t._x,l=t._y,c=t._z,u=t._w;return this._x=i*u+o*a+r*c-s*l,this._y=r*u+o*l+s*a-i*c,this._z=s*u+o*c+i*l-r*a,this._w=o*u-i*a-r*l-s*c,this._onChangeCallback(),this}slerp(e,t){if(t===0)return this;if(t===1)return this.copy(e);const i=this._x,r=this._y,s=this._z,o=this._w;let a=o*e._w+i*e._x+r*e._y+s*e._z;if(a<0?(this._w=-e._w,this._x=-e._x,this._y=-e._y,this._z=-e._z,a=-a):this.copy(e),a>=1)return this._w=o,this._x=i,this._y=r,this._z=s,this;const l=1-a*a;if(l<=Number.EPSILON){const d=1-t;return this._w=d*o+t*this._w,this._x=d*i+t*this._x,this._y=d*r+t*this._y,this._z=d*s+t*this._z,this.normalize(),this}const c=Math.sqrt(l),u=Math.atan2(c,a),h=Math.sin((1-t)*u)/c,f=Math.sin(t*u)/c;return this._w=o*h+this._w*f,this._x=i*h+this._x*f,this._y=r*h+this._y*f,this._z=s*h+this._z*f,this._onChangeCallback(),this}slerpQuaternions(e,t,i){return this.copy(e).slerp(t,i)}random(){const e=2*Math.PI*Math.random(),t=2*Math.PI*Math.random(),i=Math.random(),r=Math.sqrt(1-i),s=Math.sqrt(i);return this.set(r*Math.sin(e),r*Math.cos(e),s*Math.sin(t),s*Math.cos(t))}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._w===this._w}fromArray(e,t=0){return this._x=e[t],this._y=e[t+1],this._z=e[t+2],this._w=e[t+3],this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._w,e}fromBufferAttribute(e,t){return this._x=e.getX(t),this._y=e.getY(t),this._z=e.getZ(t),this._w=e.getW(t),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}}class O{constructor(e=0,t=0,i=0){O.prototype.isVector3=!0,this.x=e,this.y=t,this.z=i}set(e,t,i){return i===void 0&&(i=this.z),this.x=e,this.y=t,this.z=i,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;default:throw new Error("index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this}multiplyVectors(e,t){return this.x=e.x*t.x,this.y=e.y*t.y,this.z=e.z*t.z,this}applyEuler(e){return this.applyQuaternion(If.setFromEuler(e))}applyAxisAngle(e,t){return this.applyQuaternion(If.setFromAxisAngle(e,t))}applyMatrix3(e){const t=this.x,i=this.y,r=this.z,s=e.elements;return this.x=s[0]*t+s[3]*i+s[6]*r,this.y=s[1]*t+s[4]*i+s[7]*r,this.z=s[2]*t+s[5]*i+s[8]*r,this}applyNormalMatrix(e){return this.applyMatrix3(e).normalize()}applyMatrix4(e){const t=this.x,i=this.y,r=this.z,s=e.elements,o=1/(s[3]*t+s[7]*i+s[11]*r+s[15]);return this.x=(s[0]*t+s[4]*i+s[8]*r+s[12])*o,this.y=(s[1]*t+s[5]*i+s[9]*r+s[13])*o,this.z=(s[2]*t+s[6]*i+s[10]*r+s[14])*o,this}applyQuaternion(e){const t=this.x,i=this.y,r=this.z,s=e.x,o=e.y,a=e.z,l=e.w,c=2*(o*r-a*i),u=2*(a*t-s*r),h=2*(s*i-o*t);return this.x=t+l*c+o*h-a*u,this.y=i+l*u+a*c-s*h,this.z=r+l*h+s*u-o*c,this}project(e){return this.applyMatrix4(e.matrixWorldInverse).applyMatrix4(e.projectionMatrix)}unproject(e){return this.applyMatrix4(e.projectionMatrixInverse).applyMatrix4(e.matrixWorld)}transformDirection(e){const t=this.x,i=this.y,r=this.z,s=e.elements;return this.x=s[0]*t+s[4]*i+s[8]*r,this.y=s[1]*t+s[5]*i+s[9]*r,this.z=s[2]*t+s[6]*i+s[10]*r,this.normalize()}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this}divideScalar(e){return this.multiplyScalar(1/e)}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this}clamp(e,t){return this.x=Math.max(e.x,Math.min(t.x,this.x)),this.y=Math.max(e.y,Math.min(t.y,this.y)),this.z=Math.max(e.z,Math.min(t.z,this.z)),this}clampScalar(e,t){return this.x=Math.max(e,Math.min(t,this.x)),this.y=Math.max(e,Math.min(t,this.y)),this.z=Math.max(e,Math.min(t,this.z)),this}clampLength(e,t){const i=this.length();return this.divideScalar(i||1).multiplyScalar(Math.max(e,Math.min(t,i)))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this}lerpVectors(e,t,i){return this.x=e.x+(t.x-e.x)*i,this.y=e.y+(t.y-e.y)*i,this.z=e.z+(t.z-e.z)*i,this}cross(e){return this.crossVectors(this,e)}crossVectors(e,t){const i=e.x,r=e.y,s=e.z,o=t.x,a=t.y,l=t.z;return this.x=r*l-s*a,this.y=s*o-i*l,this.z=i*a-r*o,this}projectOnVector(e){const t=e.lengthSq();if(t===0)return this.set(0,0,0);const i=e.dot(this)/t;return this.copy(e).multiplyScalar(i)}projectOnPlane(e){return ac.copy(this).projectOnVector(e),this.sub(ac)}reflect(e){return this.sub(ac.copy(e).multiplyScalar(2*this.dot(e)))}angleTo(e){const t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;const i=this.dot(e)/t;return Math.acos(tn(i,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){const t=this.x-e.x,i=this.y-e.y,r=this.z-e.z;return t*t+i*i+r*r}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)+Math.abs(this.z-e.z)}setFromSpherical(e){return this.setFromSphericalCoords(e.radius,e.phi,e.theta)}setFromSphericalCoords(e,t,i){const r=Math.sin(t)*e;return this.x=r*Math.sin(i),this.y=Math.cos(t)*e,this.z=r*Math.cos(i),this}setFromCylindrical(e){return this.setFromCylindricalCoords(e.radius,e.theta,e.y)}setFromCylindricalCoords(e,t,i){return this.x=e*Math.sin(t),this.y=i,this.z=e*Math.cos(t),this}setFromMatrixPosition(e){const t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this}setFromMatrixScale(e){const t=this.setFromMatrixColumn(e,0).length(),i=this.setFromMatrixColumn(e,1).length(),r=this.setFromMatrixColumn(e,2).length();return this.x=t,this.y=i,this.z=r,this}setFromMatrixColumn(e,t){return this.fromArray(e.elements,t*4)}setFromMatrix3Column(e,t){return this.fromArray(e.elements,t*3)}setFromEuler(e){return this.x=e._x,this.y=e._y,this.z=e._z,this}setFromColor(e){return this.x=e.r,this.y=e.g,this.z=e.b,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){const e=Math.random()*Math.PI*2,t=Math.random()*2-1,i=Math.sqrt(1-t*t);return this.x=i*Math.cos(e),this.y=t,this.z=i*Math.sin(e),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}}const ac=new O,If=new Hi;class fa{constructor(e=new O(1/0,1/0,1/0),t=new O(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=e,this.max=t}set(e,t){return this.min.copy(e),this.max.copy(t),this}setFromArray(e){this.makeEmpty();for(let t=0,i=e.length;t<i;t+=3)this.expandByPoint(ti.fromArray(e,t));return this}setFromBufferAttribute(e){this.makeEmpty();for(let t=0,i=e.count;t<i;t++)this.expandByPoint(ti.fromBufferAttribute(e,t));return this}setFromPoints(e){this.makeEmpty();for(let t=0,i=e.length;t<i;t++)this.expandByPoint(e[t]);return this}setFromCenterAndSize(e,t){const i=ti.copy(t).multiplyScalar(.5);return this.min.copy(e).sub(i),this.max.copy(e).add(i),this}setFromObject(e,t=!1){return this.makeEmpty(),this.expandByObject(e,t)}clone(){return new this.constructor().copy(this)}copy(e){return this.min.copy(e.min),this.max.copy(e.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(e){return this.isEmpty()?e.set(0,0,0):e.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(e){return this.isEmpty()?e.set(0,0,0):e.subVectors(this.max,this.min)}expandByPoint(e){return this.min.min(e),this.max.max(e),this}expandByVector(e){return this.min.sub(e),this.max.add(e),this}expandByScalar(e){return this.min.addScalar(-e),this.max.addScalar(e),this}expandByObject(e,t=!1){e.updateWorldMatrix(!1,!1);const i=e.geometry;if(i!==void 0){const s=i.getAttribute("position");if(t===!0&&s!==void 0&&e.isInstancedMesh!==!0)for(let o=0,a=s.count;o<a;o++)e.isMesh===!0?e.getVertexPosition(o,ti):ti.fromBufferAttribute(s,o),ti.applyMatrix4(e.matrixWorld),this.expandByPoint(ti);else e.boundingBox!==void 0?(e.boundingBox===null&&e.computeBoundingBox(),_a.copy(e.boundingBox)):(i.boundingBox===null&&i.computeBoundingBox(),_a.copy(i.boundingBox)),_a.applyMatrix4(e.matrixWorld),this.union(_a)}const r=e.children;for(let s=0,o=r.length;s<o;s++)this.expandByObject(r[s],t);return this}containsPoint(e){return e.x>=this.min.x&&e.x<=this.max.x&&e.y>=this.min.y&&e.y<=this.max.y&&e.z>=this.min.z&&e.z<=this.max.z}containsBox(e){return this.min.x<=e.min.x&&e.max.x<=this.max.x&&this.min.y<=e.min.y&&e.max.y<=this.max.y&&this.min.z<=e.min.z&&e.max.z<=this.max.z}getParameter(e,t){return t.set((e.x-this.min.x)/(this.max.x-this.min.x),(e.y-this.min.y)/(this.max.y-this.min.y),(e.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(e){return e.max.x>=this.min.x&&e.min.x<=this.max.x&&e.max.y>=this.min.y&&e.min.y<=this.max.y&&e.max.z>=this.min.z&&e.min.z<=this.max.z}intersectsSphere(e){return this.clampPoint(e.center,ti),ti.distanceToSquared(e.center)<=e.radius*e.radius}intersectsPlane(e){let t,i;return e.normal.x>0?(t=e.normal.x*this.min.x,i=e.normal.x*this.max.x):(t=e.normal.x*this.max.x,i=e.normal.x*this.min.x),e.normal.y>0?(t+=e.normal.y*this.min.y,i+=e.normal.y*this.max.y):(t+=e.normal.y*this.max.y,i+=e.normal.y*this.min.y),e.normal.z>0?(t+=e.normal.z*this.min.z,i+=e.normal.z*this.max.z):(t+=e.normal.z*this.max.z,i+=e.normal.z*this.min.z),t<=-e.constant&&i>=-e.constant}intersectsTriangle(e){if(this.isEmpty())return!1;this.getCenter(Mo),xa.subVectors(this.max,Mo),ps.subVectors(e.a,Mo),ms.subVectors(e.b,Mo),gs.subVectors(e.c,Mo),$i.subVectors(ms,ps),Yi.subVectors(gs,ms),Cr.subVectors(ps,gs);let t=[0,-$i.z,$i.y,0,-Yi.z,Yi.y,0,-Cr.z,Cr.y,$i.z,0,-$i.x,Yi.z,0,-Yi.x,Cr.z,0,-Cr.x,-$i.y,$i.x,0,-Yi.y,Yi.x,0,-Cr.y,Cr.x,0];return!lc(t,ps,ms,gs,xa)||(t=[1,0,0,0,1,0,0,0,1],!lc(t,ps,ms,gs,xa))?!1:(ya.crossVectors($i,Yi),t=[ya.x,ya.y,ya.z],lc(t,ps,ms,gs,xa))}clampPoint(e,t){return t.copy(e).clamp(this.min,this.max)}distanceToPoint(e){return this.clampPoint(e,ti).distanceTo(e)}getBoundingSphere(e){return this.isEmpty()?e.makeEmpty():(this.getCenter(e.center),e.radius=this.getSize(ti).length()*.5),e}intersect(e){return this.min.max(e.min),this.max.min(e.max),this.isEmpty()&&this.makeEmpty(),this}union(e){return this.min.min(e.min),this.max.max(e.max),this}applyMatrix4(e){return this.isEmpty()?this:(Ai[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(e),Ai[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(e),Ai[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(e),Ai[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(e),Ai[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(e),Ai[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(e),Ai[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(e),Ai[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(e),this.setFromPoints(Ai),this)}translate(e){return this.min.add(e),this.max.add(e),this}equals(e){return e.min.equals(this.min)&&e.max.equals(this.max)}}const Ai=[new O,new O,new O,new O,new O,new O,new O,new O],ti=new O,_a=new fa,ps=new O,ms=new O,gs=new O,$i=new O,Yi=new O,Cr=new O,Mo=new O,xa=new O,ya=new O,Rr=new O;function lc(n,e,t,i,r){for(let s=0,o=n.length-3;s<=o;s+=3){Rr.fromArray(n,s);const a=r.x*Math.abs(Rr.x)+r.y*Math.abs(Rr.y)+r.z*Math.abs(Rr.z),l=e.dot(Rr),c=t.dot(Rr),u=i.dot(Rr);if(Math.max(-Math.max(l,c,u),Math.min(l,c,u))>a)return!1}return!0}const qg=new fa,bo=new O,cc=new O;class Wl{constructor(e=new O,t=-1){this.isSphere=!0,this.center=e,this.radius=t}set(e,t){return this.center.copy(e),this.radius=t,this}setFromPoints(e,t){const i=this.center;t!==void 0?i.copy(t):qg.setFromPoints(e).getCenter(i);let r=0;for(let s=0,o=e.length;s<o;s++)r=Math.max(r,i.distanceToSquared(e[s]));return this.radius=Math.sqrt(r),this}copy(e){return this.center.copy(e.center),this.radius=e.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(e){return e.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(e){return e.distanceTo(this.center)-this.radius}intersectsSphere(e){const t=this.radius+e.radius;return e.center.distanceToSquared(this.center)<=t*t}intersectsBox(e){return e.intersectsSphere(this)}intersectsPlane(e){return Math.abs(e.distanceToPoint(this.center))<=this.radius}clampPoint(e,t){const i=this.center.distanceToSquared(e);return t.copy(e),i>this.radius*this.radius&&(t.sub(this.center).normalize(),t.multiplyScalar(this.radius).add(this.center)),t}getBoundingBox(e){return this.isEmpty()?(e.makeEmpty(),e):(e.set(this.center,this.center),e.expandByScalar(this.radius),e)}applyMatrix4(e){return this.center.applyMatrix4(e),this.radius=this.radius*e.getMaxScaleOnAxis(),this}translate(e){return this.center.add(e),this}expandByPoint(e){if(this.isEmpty())return this.center.copy(e),this.radius=0,this;bo.subVectors(e,this.center);const t=bo.lengthSq();if(t>this.radius*this.radius){const i=Math.sqrt(t),r=(i-this.radius)*.5;this.center.addScaledVector(bo,r/i),this.radius+=r}return this}union(e){return e.isEmpty()?this:this.isEmpty()?(this.copy(e),this):(this.center.equals(e.center)===!0?this.radius=Math.max(this.radius,e.radius):(cc.subVectors(e.center,this.center).setLength(e.radius),this.expandByPoint(bo.copy(e.center).add(cc)),this.expandByPoint(bo.copy(e.center).sub(cc))),this)}equals(e){return e.center.equals(this.center)&&e.radius===this.radius}clone(){return new this.constructor().copy(this)}}const Ci=new O,uc=new O,Sa=new O,Ki=new O,hc=new O,Ma=new O,fc=new O;class X0{constructor(e=new O,t=new O(0,0,-1)){this.origin=e,this.direction=t}set(e,t){return this.origin.copy(e),this.direction.copy(t),this}copy(e){return this.origin.copy(e.origin),this.direction.copy(e.direction),this}at(e,t){return t.copy(this.origin).addScaledVector(this.direction,e)}lookAt(e){return this.direction.copy(e).sub(this.origin).normalize(),this}recast(e){return this.origin.copy(this.at(e,Ci)),this}closestPointToPoint(e,t){t.subVectors(e,this.origin);const i=t.dot(this.direction);return i<0?t.copy(this.origin):t.copy(this.origin).addScaledVector(this.direction,i)}distanceToPoint(e){return Math.sqrt(this.distanceSqToPoint(e))}distanceSqToPoint(e){const t=Ci.subVectors(e,this.origin).dot(this.direction);return t<0?this.origin.distanceToSquared(e):(Ci.copy(this.origin).addScaledVector(this.direction,t),Ci.distanceToSquared(e))}distanceSqToSegment(e,t,i,r){uc.copy(e).add(t).multiplyScalar(.5),Sa.copy(t).sub(e).normalize(),Ki.copy(this.origin).sub(uc);const s=e.distanceTo(t)*.5,o=-this.direction.dot(Sa),a=Ki.dot(this.direction),l=-Ki.dot(Sa),c=Ki.lengthSq(),u=Math.abs(1-o*o);let h,f,d,v;if(u>0)if(h=o*l-a,f=o*a-l,v=s*u,h>=0)if(f>=-v)if(f<=v){const g=1/u;h*=g,f*=g,d=h*(h+o*f+2*a)+f*(o*h+f+2*l)+c}else f=s,h=Math.max(0,-(o*f+a)),d=-h*h+f*(f+2*l)+c;else f=-s,h=Math.max(0,-(o*f+a)),d=-h*h+f*(f+2*l)+c;else f<=-v?(h=Math.max(0,-(-o*s+a)),f=h>0?-s:Math.min(Math.max(-s,-l),s),d=-h*h+f*(f+2*l)+c):f<=v?(h=0,f=Math.min(Math.max(-s,-l),s),d=f*(f+2*l)+c):(h=Math.max(0,-(o*s+a)),f=h>0?s:Math.min(Math.max(-s,-l),s),d=-h*h+f*(f+2*l)+c);else f=o>0?-s:s,h=Math.max(0,-(o*f+a)),d=-h*h+f*(f+2*l)+c;return i&&i.copy(this.origin).addScaledVector(this.direction,h),r&&r.copy(uc).addScaledVector(Sa,f),d}intersectSphere(e,t){Ci.subVectors(e.center,this.origin);const i=Ci.dot(this.direction),r=Ci.dot(Ci)-i*i,s=e.radius*e.radius;if(r>s)return null;const o=Math.sqrt(s-r),a=i-o,l=i+o;return l<0?null:a<0?this.at(l,t):this.at(a,t)}intersectsSphere(e){return this.distanceSqToPoint(e.center)<=e.radius*e.radius}distanceToPlane(e){const t=e.normal.dot(this.direction);if(t===0)return e.distanceToPoint(this.origin)===0?0:null;const i=-(this.origin.dot(e.normal)+e.constant)/t;return i>=0?i:null}intersectPlane(e,t){const i=this.distanceToPlane(e);return i===null?null:this.at(i,t)}intersectsPlane(e){const t=e.distanceToPoint(this.origin);return t===0||e.normal.dot(this.direction)*t<0}intersectBox(e,t){let i,r,s,o,a,l;const c=1/this.direction.x,u=1/this.direction.y,h=1/this.direction.z,f=this.origin;return c>=0?(i=(e.min.x-f.x)*c,r=(e.max.x-f.x)*c):(i=(e.max.x-f.x)*c,r=(e.min.x-f.x)*c),u>=0?(s=(e.min.y-f.y)*u,o=(e.max.y-f.y)*u):(s=(e.max.y-f.y)*u,o=(e.min.y-f.y)*u),i>o||s>r||((s>i||isNaN(i))&&(i=s),(o<r||isNaN(r))&&(r=o),h>=0?(a=(e.min.z-f.z)*h,l=(e.max.z-f.z)*h):(a=(e.max.z-f.z)*h,l=(e.min.z-f.z)*h),i>l||a>r)||((a>i||i!==i)&&(i=a),(l<r||r!==r)&&(r=l),r<0)?null:this.at(i>=0?i:r,t)}intersectsBox(e){return this.intersectBox(e,Ci)!==null}intersectTriangle(e,t,i,r,s){hc.subVectors(t,e),Ma.subVectors(i,e),fc.crossVectors(hc,Ma);let o=this.direction.dot(fc),a;if(o>0){if(r)return null;a=1}else if(o<0)a=-1,o=-o;else return null;Ki.subVectors(this.origin,e);const l=a*this.direction.dot(Ma.crossVectors(Ki,Ma));if(l<0)return null;const c=a*this.direction.dot(hc.cross(Ki));if(c<0||l+c>o)return null;const u=-a*Ki.dot(fc);return u<0?null:this.at(u/o,s)}applyMatrix4(e){return this.origin.applyMatrix4(e),this.direction.transformDirection(e),this}equals(e){return e.origin.equals(this.origin)&&e.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}}class It{constructor(e,t,i,r,s,o,a,l,c,u,h,f,d,v,g,p){It.prototype.isMatrix4=!0,this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],e!==void 0&&this.set(e,t,i,r,s,o,a,l,c,u,h,f,d,v,g,p)}set(e,t,i,r,s,o,a,l,c,u,h,f,d,v,g,p){const m=this.elements;return m[0]=e,m[4]=t,m[8]=i,m[12]=r,m[1]=s,m[5]=o,m[9]=a,m[13]=l,m[2]=c,m[6]=u,m[10]=h,m[14]=f,m[3]=d,m[7]=v,m[11]=g,m[15]=p,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new It().fromArray(this.elements)}copy(e){const t=this.elements,i=e.elements;return t[0]=i[0],t[1]=i[1],t[2]=i[2],t[3]=i[3],t[4]=i[4],t[5]=i[5],t[6]=i[6],t[7]=i[7],t[8]=i[8],t[9]=i[9],t[10]=i[10],t[11]=i[11],t[12]=i[12],t[13]=i[13],t[14]=i[14],t[15]=i[15],this}copyPosition(e){const t=this.elements,i=e.elements;return t[12]=i[12],t[13]=i[13],t[14]=i[14],this}setFromMatrix3(e){const t=e.elements;return this.set(t[0],t[3],t[6],0,t[1],t[4],t[7],0,t[2],t[5],t[8],0,0,0,0,1),this}extractBasis(e,t,i){return e.setFromMatrixColumn(this,0),t.setFromMatrixColumn(this,1),i.setFromMatrixColumn(this,2),this}makeBasis(e,t,i){return this.set(e.x,t.x,i.x,0,e.y,t.y,i.y,0,e.z,t.z,i.z,0,0,0,0,1),this}extractRotation(e){const t=this.elements,i=e.elements,r=1/vs.setFromMatrixColumn(e,0).length(),s=1/vs.setFromMatrixColumn(e,1).length(),o=1/vs.setFromMatrixColumn(e,2).length();return t[0]=i[0]*r,t[1]=i[1]*r,t[2]=i[2]*r,t[3]=0,t[4]=i[4]*s,t[5]=i[5]*s,t[6]=i[6]*s,t[7]=0,t[8]=i[8]*o,t[9]=i[9]*o,t[10]=i[10]*o,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromEuler(e){const t=this.elements,i=e.x,r=e.y,s=e.z,o=Math.cos(i),a=Math.sin(i),l=Math.cos(r),c=Math.sin(r),u=Math.cos(s),h=Math.sin(s);if(e.order==="XYZ"){const f=o*u,d=o*h,v=a*u,g=a*h;t[0]=l*u,t[4]=-l*h,t[8]=c,t[1]=d+v*c,t[5]=f-g*c,t[9]=-a*l,t[2]=g-f*c,t[6]=v+d*c,t[10]=o*l}else if(e.order==="YXZ"){const f=l*u,d=l*h,v=c*u,g=c*h;t[0]=f+g*a,t[4]=v*a-d,t[8]=o*c,t[1]=o*h,t[5]=o*u,t[9]=-a,t[2]=d*a-v,t[6]=g+f*a,t[10]=o*l}else if(e.order==="ZXY"){const f=l*u,d=l*h,v=c*u,g=c*h;t[0]=f-g*a,t[4]=-o*h,t[8]=v+d*a,t[1]=d+v*a,t[5]=o*u,t[9]=g-f*a,t[2]=-o*c,t[6]=a,t[10]=o*l}else if(e.order==="ZYX"){const f=o*u,d=o*h,v=a*u,g=a*h;t[0]=l*u,t[4]=v*c-d,t[8]=f*c+g,t[1]=l*h,t[5]=g*c+f,t[9]=d*c-v,t[2]=-c,t[6]=a*l,t[10]=o*l}else if(e.order==="YZX"){const f=o*l,d=o*c,v=a*l,g=a*c;t[0]=l*u,t[4]=g-f*h,t[8]=v*h+d,t[1]=h,t[5]=o*u,t[9]=-a*u,t[2]=-c*u,t[6]=d*h+v,t[10]=f-g*h}else if(e.order==="XZY"){const f=o*l,d=o*c,v=a*l,g=a*c;t[0]=l*u,t[4]=-h,t[8]=c*u,t[1]=f*h+g,t[5]=o*u,t[9]=d*h-v,t[2]=v*h-d,t[6]=a*u,t[10]=g*h+f}return t[3]=0,t[7]=0,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromQuaternion(e){return this.compose($g,e,Yg)}lookAt(e,t,i){const r=this.elements;return In.subVectors(e,t),In.lengthSq()===0&&(In.z=1),In.normalize(),ji.crossVectors(i,In),ji.lengthSq()===0&&(Math.abs(i.z)===1?In.x+=1e-4:In.z+=1e-4,In.normalize(),ji.crossVectors(i,In)),ji.normalize(),ba.crossVectors(In,ji),r[0]=ji.x,r[4]=ba.x,r[8]=In.x,r[1]=ji.y,r[5]=ba.y,r[9]=In.y,r[2]=ji.z,r[6]=ba.z,r[10]=In.z,this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){const i=e.elements,r=t.elements,s=this.elements,o=i[0],a=i[4],l=i[8],c=i[12],u=i[1],h=i[5],f=i[9],d=i[13],v=i[2],g=i[6],p=i[10],m=i[14],x=i[3],_=i[7],y=i[11],C=i[15],M=r[0],w=r[4],P=r[8],I=r[12],S=r[1],b=r[5],N=r[9],R=r[13],H=r[2],T=r[6],k=r[10],Z=r[14],K=r[3],pe=r[7],ce=r[11],W=r[15];return s[0]=o*M+a*S+l*H+c*K,s[4]=o*w+a*b+l*T+c*pe,s[8]=o*P+a*N+l*k+c*ce,s[12]=o*I+a*R+l*Z+c*W,s[1]=u*M+h*S+f*H+d*K,s[5]=u*w+h*b+f*T+d*pe,s[9]=u*P+h*N+f*k+d*ce,s[13]=u*I+h*R+f*Z+d*W,s[2]=v*M+g*S+p*H+m*K,s[6]=v*w+g*b+p*T+m*pe,s[10]=v*P+g*N+p*k+m*ce,s[14]=v*I+g*R+p*Z+m*W,s[3]=x*M+_*S+y*H+C*K,s[7]=x*w+_*b+y*T+C*pe,s[11]=x*P+_*N+y*k+C*ce,s[15]=x*I+_*R+y*Z+C*W,this}multiplyScalar(e){const t=this.elements;return t[0]*=e,t[4]*=e,t[8]*=e,t[12]*=e,t[1]*=e,t[5]*=e,t[9]*=e,t[13]*=e,t[2]*=e,t[6]*=e,t[10]*=e,t[14]*=e,t[3]*=e,t[7]*=e,t[11]*=e,t[15]*=e,this}determinant(){const e=this.elements,t=e[0],i=e[4],r=e[8],s=e[12],o=e[1],a=e[5],l=e[9],c=e[13],u=e[2],h=e[6],f=e[10],d=e[14],v=e[3],g=e[7],p=e[11],m=e[15];return v*(+s*l*h-r*c*h-s*a*f+i*c*f+r*a*d-i*l*d)+g*(+t*l*d-t*c*f+s*o*f-r*o*d+r*c*u-s*l*u)+p*(+t*c*h-t*a*d-s*o*h+i*o*d+s*a*u-i*c*u)+m*(-r*a*u-t*l*h+t*a*f+r*o*h-i*o*f+i*l*u)}transpose(){const e=this.elements;let t;return t=e[1],e[1]=e[4],e[4]=t,t=e[2],e[2]=e[8],e[8]=t,t=e[6],e[6]=e[9],e[9]=t,t=e[3],e[3]=e[12],e[12]=t,t=e[7],e[7]=e[13],e[13]=t,t=e[11],e[11]=e[14],e[14]=t,this}setPosition(e,t,i){const r=this.elements;return e.isVector3?(r[12]=e.x,r[13]=e.y,r[14]=e.z):(r[12]=e,r[13]=t,r[14]=i),this}invert(){const e=this.elements,t=e[0],i=e[1],r=e[2],s=e[3],o=e[4],a=e[5],l=e[6],c=e[7],u=e[8],h=e[9],f=e[10],d=e[11],v=e[12],g=e[13],p=e[14],m=e[15],x=h*p*c-g*f*c+g*l*d-a*p*d-h*l*m+a*f*m,_=v*f*c-u*p*c-v*l*d+o*p*d+u*l*m-o*f*m,y=u*g*c-v*h*c+v*a*d-o*g*d-u*a*m+o*h*m,C=v*h*l-u*g*l-v*a*f+o*g*f+u*a*p-o*h*p,M=t*x+i*_+r*y+s*C;if(M===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);const w=1/M;return e[0]=x*w,e[1]=(g*f*s-h*p*s-g*r*d+i*p*d+h*r*m-i*f*m)*w,e[2]=(a*p*s-g*l*s+g*r*c-i*p*c-a*r*m+i*l*m)*w,e[3]=(h*l*s-a*f*s-h*r*c+i*f*c+a*r*d-i*l*d)*w,e[4]=_*w,e[5]=(u*p*s-v*f*s+v*r*d-t*p*d-u*r*m+t*f*m)*w,e[6]=(v*l*s-o*p*s-v*r*c+t*p*c+o*r*m-t*l*m)*w,e[7]=(o*f*s-u*l*s+u*r*c-t*f*c-o*r*d+t*l*d)*w,e[8]=y*w,e[9]=(v*h*s-u*g*s-v*i*d+t*g*d+u*i*m-t*h*m)*w,e[10]=(o*g*s-v*a*s+v*i*c-t*g*c-o*i*m+t*a*m)*w,e[11]=(u*a*s-o*h*s-u*i*c+t*h*c+o*i*d-t*a*d)*w,e[12]=C*w,e[13]=(u*g*r-v*h*r+v*i*f-t*g*f-u*i*p+t*h*p)*w,e[14]=(v*a*r-o*g*r-v*i*l+t*g*l+o*i*p-t*a*p)*w,e[15]=(o*h*r-u*a*r+u*i*l-t*h*l-o*i*f+t*a*f)*w,this}scale(e){const t=this.elements,i=e.x,r=e.y,s=e.z;return t[0]*=i,t[4]*=r,t[8]*=s,t[1]*=i,t[5]*=r,t[9]*=s,t[2]*=i,t[6]*=r,t[10]*=s,t[3]*=i,t[7]*=r,t[11]*=s,this}getMaxScaleOnAxis(){const e=this.elements,t=e[0]*e[0]+e[1]*e[1]+e[2]*e[2],i=e[4]*e[4]+e[5]*e[5]+e[6]*e[6],r=e[8]*e[8]+e[9]*e[9]+e[10]*e[10];return Math.sqrt(Math.max(t,i,r))}makeTranslation(e,t,i){return e.isVector3?this.set(1,0,0,e.x,0,1,0,e.y,0,0,1,e.z,0,0,0,1):this.set(1,0,0,e,0,1,0,t,0,0,1,i,0,0,0,1),this}makeRotationX(e){const t=Math.cos(e),i=Math.sin(e);return this.set(1,0,0,0,0,t,-i,0,0,i,t,0,0,0,0,1),this}makeRotationY(e){const t=Math.cos(e),i=Math.sin(e);return this.set(t,0,i,0,0,1,0,0,-i,0,t,0,0,0,0,1),this}makeRotationZ(e){const t=Math.cos(e),i=Math.sin(e);return this.set(t,-i,0,0,i,t,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(e,t){const i=Math.cos(t),r=Math.sin(t),s=1-i,o=e.x,a=e.y,l=e.z,c=s*o,u=s*a;return this.set(c*o+i,c*a-r*l,c*l+r*a,0,c*a+r*l,u*a+i,u*l-r*o,0,c*l-r*a,u*l+r*o,s*l*l+i,0,0,0,0,1),this}makeScale(e,t,i){return this.set(e,0,0,0,0,t,0,0,0,0,i,0,0,0,0,1),this}makeShear(e,t,i,r,s,o){return this.set(1,i,s,0,e,1,o,0,t,r,1,0,0,0,0,1),this}compose(e,t,i){const r=this.elements,s=t._x,o=t._y,a=t._z,l=t._w,c=s+s,u=o+o,h=a+a,f=s*c,d=s*u,v=s*h,g=o*u,p=o*h,m=a*h,x=l*c,_=l*u,y=l*h,C=i.x,M=i.y,w=i.z;return r[0]=(1-(g+m))*C,r[1]=(d+y)*C,r[2]=(v-_)*C,r[3]=0,r[4]=(d-y)*M,r[5]=(1-(f+m))*M,r[6]=(p+x)*M,r[7]=0,r[8]=(v+_)*w,r[9]=(p-x)*w,r[10]=(1-(f+g))*w,r[11]=0,r[12]=e.x,r[13]=e.y,r[14]=e.z,r[15]=1,this}decompose(e,t,i){const r=this.elements;let s=vs.set(r[0],r[1],r[2]).length();const o=vs.set(r[4],r[5],r[6]).length(),a=vs.set(r[8],r[9],r[10]).length();this.determinant()<0&&(s=-s),e.x=r[12],e.y=r[13],e.z=r[14],ni.copy(this);const c=1/s,u=1/o,h=1/a;return ni.elements[0]*=c,ni.elements[1]*=c,ni.elements[2]*=c,ni.elements[4]*=u,ni.elements[5]*=u,ni.elements[6]*=u,ni.elements[8]*=h,ni.elements[9]*=h,ni.elements[10]*=h,t.setFromRotationMatrix(ni),i.x=s,i.y=o,i.z=a,this}makePerspective(e,t,i,r,s,o,a=Oi){const l=this.elements,c=2*s/(t-e),u=2*s/(i-r),h=(t+e)/(t-e),f=(i+r)/(i-r);let d,v;if(a===Oi)d=-(o+s)/(o-s),v=-2*o*s/(o-s);else if(a===bl)d=-o/(o-s),v=-o*s/(o-s);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+a);return l[0]=c,l[4]=0,l[8]=h,l[12]=0,l[1]=0,l[5]=u,l[9]=f,l[13]=0,l[2]=0,l[6]=0,l[10]=d,l[14]=v,l[3]=0,l[7]=0,l[11]=-1,l[15]=0,this}makeOrthographic(e,t,i,r,s,o,a=Oi){const l=this.elements,c=1/(t-e),u=1/(i-r),h=1/(o-s),f=(t+e)*c,d=(i+r)*u;let v,g;if(a===Oi)v=(o+s)*h,g=-2*h;else if(a===bl)v=s*h,g=-1*h;else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+a);return l[0]=2*c,l[4]=0,l[8]=0,l[12]=-f,l[1]=0,l[5]=2*u,l[9]=0,l[13]=-d,l[2]=0,l[6]=0,l[10]=g,l[14]=-v,l[3]=0,l[7]=0,l[11]=0,l[15]=1,this}equals(e){const t=this.elements,i=e.elements;for(let r=0;r<16;r++)if(t[r]!==i[r])return!1;return!0}fromArray(e,t=0){for(let i=0;i<16;i++)this.elements[i]=e[i+t];return this}toArray(e=[],t=0){const i=this.elements;return e[t]=i[0],e[t+1]=i[1],e[t+2]=i[2],e[t+3]=i[3],e[t+4]=i[4],e[t+5]=i[5],e[t+6]=i[6],e[t+7]=i[7],e[t+8]=i[8],e[t+9]=i[9],e[t+10]=i[10],e[t+11]=i[11],e[t+12]=i[12],e[t+13]=i[13],e[t+14]=i[14],e[t+15]=i[15],e}}const vs=new O,ni=new It,$g=new O(0,0,0),Yg=new O(1,1,1),ji=new O,ba=new O,In=new O,Uf=new It,Nf=new Hi;class Mi{constructor(e=0,t=0,i=0,r=Mi.DEFAULT_ORDER){this.isEuler=!0,this._x=e,this._y=t,this._z=i,this._order=r}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get order(){return this._order}set order(e){this._order=e,this._onChangeCallback()}set(e,t,i,r=this._order){return this._x=e,this._y=t,this._z=i,this._order=r,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(e){return this._x=e._x,this._y=e._y,this._z=e._z,this._order=e._order,this._onChangeCallback(),this}setFromRotationMatrix(e,t=this._order,i=!0){const r=e.elements,s=r[0],o=r[4],a=r[8],l=r[1],c=r[5],u=r[9],h=r[2],f=r[6],d=r[10];switch(t){case"XYZ":this._y=Math.asin(tn(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(-u,d),this._z=Math.atan2(-o,s)):(this._x=Math.atan2(f,c),this._z=0);break;case"YXZ":this._x=Math.asin(-tn(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(a,d),this._z=Math.atan2(l,c)):(this._y=Math.atan2(-h,s),this._z=0);break;case"ZXY":this._x=Math.asin(tn(f,-1,1)),Math.abs(f)<.9999999?(this._y=Math.atan2(-h,d),this._z=Math.atan2(-o,c)):(this._y=0,this._z=Math.atan2(l,s));break;case"ZYX":this._y=Math.asin(-tn(h,-1,1)),Math.abs(h)<.9999999?(this._x=Math.atan2(f,d),this._z=Math.atan2(l,s)):(this._x=0,this._z=Math.atan2(-o,c));break;case"YZX":this._z=Math.asin(tn(l,-1,1)),Math.abs(l)<.9999999?(this._x=Math.atan2(-u,c),this._y=Math.atan2(-h,s)):(this._x=0,this._y=Math.atan2(a,d));break;case"XZY":this._z=Math.asin(-tn(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(f,c),this._y=Math.atan2(a,s)):(this._x=Math.atan2(-u,d),this._y=0);break;default:console.warn("THREE.Euler: .setFromRotationMatrix() encountered an unknown order: "+t)}return this._order=t,i===!0&&this._onChangeCallback(),this}setFromQuaternion(e,t,i){return Uf.makeRotationFromQuaternion(e),this.setFromRotationMatrix(Uf,t,i)}setFromVector3(e,t=this._order){return this.set(e.x,e.y,e.z,t)}reorder(e){return Nf.setFromEuler(this),this.setFromQuaternion(Nf,e)}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._order===this._order}fromArray(e){return this._x=e[0],this._y=e[1],this._z=e[2],e[3]!==void 0&&(this._order=e[3]),this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._order,e}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}}Mi.DEFAULT_ORDER="XYZ";class q0{constructor(){this.mask=1}set(e){this.mask=(1<<e|0)>>>0}enable(e){this.mask|=1<<e|0}enableAll(){this.mask=-1}toggle(e){this.mask^=1<<e|0}disable(e){this.mask&=~(1<<e|0)}disableAll(){this.mask=0}test(e){return(this.mask&e.mask)!==0}isEnabled(e){return(this.mask&(1<<e|0))!==0}}let Kg=0;const Ff=new O,_s=new Hi,Ri=new It,wa=new O,wo=new O,jg=new O,Zg=new Hi,Of=new O(1,0,0),kf=new O(0,1,0),Bf=new O(0,0,1),zf={type:"added"},Jg={type:"removed"},xs={type:"childadded",child:null},dc={type:"childremoved",child:null};class yn extends Wi{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:Kg++}),this.uuid=ss(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=yn.DEFAULT_UP.clone();const e=new O,t=new Mi,i=new Hi,r=new O(1,1,1);function s(){i.setFromEuler(t,!1)}function o(){t.setFromQuaternion(i,void 0,!1)}t._onChange(s),i._onChange(o),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:e},rotation:{configurable:!0,enumerable:!0,value:t},quaternion:{configurable:!0,enumerable:!0,value:i},scale:{configurable:!0,enumerable:!0,value:r},modelViewMatrix:{value:new It},normalMatrix:{value:new tt}}),this.matrix=new It,this.matrixWorld=new It,this.matrixAutoUpdate=yn.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=yn.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new q0,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.userData={}}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(e){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(e),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(e){return this.quaternion.premultiply(e),this}setRotationFromAxisAngle(e,t){this.quaternion.setFromAxisAngle(e,t)}setRotationFromEuler(e){this.quaternion.setFromEuler(e,!0)}setRotationFromMatrix(e){this.quaternion.setFromRotationMatrix(e)}setRotationFromQuaternion(e){this.quaternion.copy(e)}rotateOnAxis(e,t){return _s.setFromAxisAngle(e,t),this.quaternion.multiply(_s),this}rotateOnWorldAxis(e,t){return _s.setFromAxisAngle(e,t),this.quaternion.premultiply(_s),this}rotateX(e){return this.rotateOnAxis(Of,e)}rotateY(e){return this.rotateOnAxis(kf,e)}rotateZ(e){return this.rotateOnAxis(Bf,e)}translateOnAxis(e,t){return Ff.copy(e).applyQuaternion(this.quaternion),this.position.add(Ff.multiplyScalar(t)),this}translateX(e){return this.translateOnAxis(Of,e)}translateY(e){return this.translateOnAxis(kf,e)}translateZ(e){return this.translateOnAxis(Bf,e)}localToWorld(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(this.matrixWorld)}worldToLocal(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(Ri.copy(this.matrixWorld).invert())}lookAt(e,t,i){e.isVector3?wa.copy(e):wa.set(e,t,i);const r=this.parent;this.updateWorldMatrix(!0,!1),wo.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?Ri.lookAt(wo,wa,this.up):Ri.lookAt(wa,wo,this.up),this.quaternion.setFromRotationMatrix(Ri),r&&(Ri.extractRotation(r.matrixWorld),_s.setFromRotationMatrix(Ri),this.quaternion.premultiply(_s.invert()))}add(e){if(arguments.length>1){for(let t=0;t<arguments.length;t++)this.add(arguments[t]);return this}return e===this?(console.error("THREE.Object3D.add: object can't be added as a child of itself.",e),this):(e&&e.isObject3D?(e.removeFromParent(),e.parent=this,this.children.push(e),e.dispatchEvent(zf),xs.child=e,this.dispatchEvent(xs),xs.child=null):console.error("THREE.Object3D.add: object not an instance of THREE.Object3D.",e),this)}remove(e){if(arguments.length>1){for(let i=0;i<arguments.length;i++)this.remove(arguments[i]);return this}const t=this.children.indexOf(e);return t!==-1&&(e.parent=null,this.children.splice(t,1),e.dispatchEvent(Jg),dc.child=e,this.dispatchEvent(dc),dc.child=null),this}removeFromParent(){const e=this.parent;return e!==null&&e.remove(this),this}clear(){return this.remove(...this.children)}attach(e){return this.updateWorldMatrix(!0,!1),Ri.copy(this.matrixWorld).invert(),e.parent!==null&&(e.parent.updateWorldMatrix(!0,!1),Ri.multiply(e.parent.matrixWorld)),e.applyMatrix4(Ri),e.removeFromParent(),e.parent=this,this.children.push(e),e.updateWorldMatrix(!1,!0),e.dispatchEvent(zf),xs.child=e,this.dispatchEvent(xs),xs.child=null,this}getObjectById(e){return this.getObjectByProperty("id",e)}getObjectByName(e){return this.getObjectByProperty("name",e)}getObjectByProperty(e,t){if(this[e]===t)return this;for(let i=0,r=this.children.length;i<r;i++){const o=this.children[i].getObjectByProperty(e,t);if(o!==void 0)return o}}getObjectsByProperty(e,t,i=[]){this[e]===t&&i.push(this);const r=this.children;for(let s=0,o=r.length;s<o;s++)r[s].getObjectsByProperty(e,t,i);return i}getWorldPosition(e){return this.updateWorldMatrix(!0,!1),e.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(wo,e,jg),e}getWorldScale(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(wo,Zg,e),e}getWorldDirection(e){this.updateWorldMatrix(!0,!1);const t=this.matrixWorld.elements;return e.set(t[8],t[9],t[10]).normalize()}raycast(){}traverse(e){e(this);const t=this.children;for(let i=0,r=t.length;i<r;i++)t[i].traverse(e)}traverseVisible(e){if(this.visible===!1)return;e(this);const t=this.children;for(let i=0,r=t.length;i<r;i++)t[i].traverseVisible(e)}traverseAncestors(e){const t=this.parent;t!==null&&(e(t),t.traverseAncestors(e))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale),this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(e){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||e)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,e=!0);const t=this.children;for(let i=0,r=t.length;i<r;i++)t[i].updateMatrixWorld(e)}updateWorldMatrix(e,t){const i=this.parent;if(e===!0&&i!==null&&i.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),t===!0){const r=this.children;for(let s=0,o=r.length;s<o;s++)r[s].updateWorldMatrix(!1,!0)}}toJSON(e){const t=e===void 0||typeof e=="string",i={};t&&(e={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},i.metadata={version:4.6,type:"Object",generator:"Object3D.toJSON"});const r={};r.uuid=this.uuid,r.type=this.type,this.name!==""&&(r.name=this.name),this.castShadow===!0&&(r.castShadow=!0),this.receiveShadow===!0&&(r.receiveShadow=!0),this.visible===!1&&(r.visible=!1),this.frustumCulled===!1&&(r.frustumCulled=!1),this.renderOrder!==0&&(r.renderOrder=this.renderOrder),Object.keys(this.userData).length>0&&(r.userData=this.userData),r.layers=this.layers.mask,r.matrix=this.matrix.toArray(),r.up=this.up.toArray(),this.matrixAutoUpdate===!1&&(r.matrixAutoUpdate=!1),this.isInstancedMesh&&(r.type="InstancedMesh",r.count=this.count,r.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(r.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(r.type="BatchedMesh",r.perObjectFrustumCulled=this.perObjectFrustumCulled,r.sortObjects=this.sortObjects,r.drawRanges=this._drawRanges,r.reservedRanges=this._reservedRanges,r.visibility=this._visibility,r.active=this._active,r.bounds=this._bounds.map(a=>({boxInitialized:a.boxInitialized,boxMin:a.box.min.toArray(),boxMax:a.box.max.toArray(),sphereInitialized:a.sphereInitialized,sphereRadius:a.sphere.radius,sphereCenter:a.sphere.center.toArray()})),r.maxInstanceCount=this._maxInstanceCount,r.maxVertexCount=this._maxVertexCount,r.maxIndexCount=this._maxIndexCount,r.geometryInitialized=this._geometryInitialized,r.geometryCount=this._geometryCount,r.matricesTexture=this._matricesTexture.toJSON(e),this._colorsTexture!==null&&(r.colorsTexture=this._colorsTexture.toJSON(e)),this.boundingSphere!==null&&(r.boundingSphere={center:r.boundingSphere.center.toArray(),radius:r.boundingSphere.radius}),this.boundingBox!==null&&(r.boundingBox={min:r.boundingBox.min.toArray(),max:r.boundingBox.max.toArray()}));function s(a,l){return a[l.uuid]===void 0&&(a[l.uuid]=l.toJSON(e)),l.uuid}if(this.isScene)this.background&&(this.background.isColor?r.background=this.background.toJSON():this.background.isTexture&&(r.background=this.background.toJSON(e).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(r.environment=this.environment.toJSON(e).uuid);else if(this.isMesh||this.isLine||this.isPoints){r.geometry=s(e.geometries,this.geometry);const a=this.geometry.parameters;if(a!==void 0&&a.shapes!==void 0){const l=a.shapes;if(Array.isArray(l))for(let c=0,u=l.length;c<u;c++){const h=l[c];s(e.shapes,h)}else s(e.shapes,l)}}if(this.isSkinnedMesh&&(r.bindMode=this.bindMode,r.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(s(e.skeletons,this.skeleton),r.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){const a=[];for(let l=0,c=this.material.length;l<c;l++)a.push(s(e.materials,this.material[l]));r.material=a}else r.material=s(e.materials,this.material);if(this.children.length>0){r.children=[];for(let a=0;a<this.children.length;a++)r.children.push(this.children[a].toJSON(e).object)}if(this.animations.length>0){r.animations=[];for(let a=0;a<this.animations.length;a++){const l=this.animations[a];r.animations.push(s(e.animations,l))}}if(t){const a=o(e.geometries),l=o(e.materials),c=o(e.textures),u=o(e.images),h=o(e.shapes),f=o(e.skeletons),d=o(e.animations),v=o(e.nodes);a.length>0&&(i.geometries=a),l.length>0&&(i.materials=l),c.length>0&&(i.textures=c),u.length>0&&(i.images=u),h.length>0&&(i.shapes=h),f.length>0&&(i.skeletons=f),d.length>0&&(i.animations=d),v.length>0&&(i.nodes=v)}return i.object=r,i;function o(a){const l=[];for(const c in a){const u=a[c];delete u.metadata,l.push(u)}return l}}clone(e){return new this.constructor().copy(this,e)}copy(e,t=!0){if(this.name=e.name,this.up.copy(e.up),this.position.copy(e.position),this.rotation.order=e.rotation.order,this.quaternion.copy(e.quaternion),this.scale.copy(e.scale),this.matrix.copy(e.matrix),this.matrixWorld.copy(e.matrixWorld),this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrixWorldAutoUpdate=e.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=e.matrixWorldNeedsUpdate,this.layers.mask=e.layers.mask,this.visible=e.visible,this.castShadow=e.castShadow,this.receiveShadow=e.receiveShadow,this.frustumCulled=e.frustumCulled,this.renderOrder=e.renderOrder,this.animations=e.animations.slice(),this.userData=JSON.parse(JSON.stringify(e.userData)),t===!0)for(let i=0;i<e.children.length;i++){const r=e.children[i];this.add(r.clone())}return this}}yn.DEFAULT_UP=new O(0,1,0);yn.DEFAULT_MATRIX_AUTO_UPDATE=!0;yn.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;const ii=new O,Pi=new O,pc=new O,Li=new O,ys=new O,Ss=new O,Hf=new O,mc=new O,gc=new O,vc=new O,_c=new Ct,xc=new Ct,yc=new Ct;class Bn{constructor(e=new O,t=new O,i=new O){this.a=e,this.b=t,this.c=i}static getNormal(e,t,i,r){r.subVectors(i,t),ii.subVectors(e,t),r.cross(ii);const s=r.lengthSq();return s>0?r.multiplyScalar(1/Math.sqrt(s)):r.set(0,0,0)}static getBarycoord(e,t,i,r,s){ii.subVectors(r,t),Pi.subVectors(i,t),pc.subVectors(e,t);const o=ii.dot(ii),a=ii.dot(Pi),l=ii.dot(pc),c=Pi.dot(Pi),u=Pi.dot(pc),h=o*c-a*a;if(h===0)return s.set(0,0,0),null;const f=1/h,d=(c*l-a*u)*f,v=(o*u-a*l)*f;return s.set(1-d-v,v,d)}static containsPoint(e,t,i,r){return this.getBarycoord(e,t,i,r,Li)===null?!1:Li.x>=0&&Li.y>=0&&Li.x+Li.y<=1}static getInterpolation(e,t,i,r,s,o,a,l){return this.getBarycoord(e,t,i,r,Li)===null?(l.x=0,l.y=0,"z"in l&&(l.z=0),"w"in l&&(l.w=0),null):(l.setScalar(0),l.addScaledVector(s,Li.x),l.addScaledVector(o,Li.y),l.addScaledVector(a,Li.z),l)}static getInterpolatedAttribute(e,t,i,r,s,o){return _c.setScalar(0),xc.setScalar(0),yc.setScalar(0),_c.fromBufferAttribute(e,t),xc.fromBufferAttribute(e,i),yc.fromBufferAttribute(e,r),o.setScalar(0),o.addScaledVector(_c,s.x),o.addScaledVector(xc,s.y),o.addScaledVector(yc,s.z),o}static isFrontFacing(e,t,i,r){return ii.subVectors(i,t),Pi.subVectors(e,t),ii.cross(Pi).dot(r)<0}set(e,t,i){return this.a.copy(e),this.b.copy(t),this.c.copy(i),this}setFromPointsAndIndices(e,t,i,r){return this.a.copy(e[t]),this.b.copy(e[i]),this.c.copy(e[r]),this}setFromAttributeAndIndices(e,t,i,r){return this.a.fromBufferAttribute(e,t),this.b.fromBufferAttribute(e,i),this.c.fromBufferAttribute(e,r),this}clone(){return new this.constructor().copy(this)}copy(e){return this.a.copy(e.a),this.b.copy(e.b),this.c.copy(e.c),this}getArea(){return ii.subVectors(this.c,this.b),Pi.subVectors(this.a,this.b),ii.cross(Pi).length()*.5}getMidpoint(e){return e.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(e){return Bn.getNormal(this.a,this.b,this.c,e)}getPlane(e){return e.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(e,t){return Bn.getBarycoord(e,this.a,this.b,this.c,t)}getInterpolation(e,t,i,r,s){return Bn.getInterpolation(e,this.a,this.b,this.c,t,i,r,s)}containsPoint(e){return Bn.containsPoint(e,this.a,this.b,this.c)}isFrontFacing(e){return Bn.isFrontFacing(this.a,this.b,this.c,e)}intersectsBox(e){return e.intersectsTriangle(this)}closestPointToPoint(e,t){const i=this.a,r=this.b,s=this.c;let o,a;ys.subVectors(r,i),Ss.subVectors(s,i),mc.subVectors(e,i);const l=ys.dot(mc),c=Ss.dot(mc);if(l<=0&&c<=0)return t.copy(i);gc.subVectors(e,r);const u=ys.dot(gc),h=Ss.dot(gc);if(u>=0&&h<=u)return t.copy(r);const f=l*h-u*c;if(f<=0&&l>=0&&u<=0)return o=l/(l-u),t.copy(i).addScaledVector(ys,o);vc.subVectors(e,s);const d=ys.dot(vc),v=Ss.dot(vc);if(v>=0&&d<=v)return t.copy(s);const g=d*c-l*v;if(g<=0&&c>=0&&v<=0)return a=c/(c-v),t.copy(i).addScaledVector(Ss,a);const p=u*v-d*h;if(p<=0&&h-u>=0&&d-v>=0)return Hf.subVectors(s,r),a=(h-u)/(h-u+(d-v)),t.copy(r).addScaledVector(Hf,a);const m=1/(p+g+f);return o=g*m,a=f*m,t.copy(i).addScaledVector(ys,o).addScaledVector(Ss,a)}equals(e){return e.a.equals(this.a)&&e.b.equals(this.b)&&e.c.equals(this.c)}}const $0={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},Zi={h:0,s:0,l:0},Ea={h:0,s:0,l:0};function Sc(n,e,t){return t<0&&(t+=1),t>1&&(t-=1),t<1/6?n+(e-n)*6*t:t<1/2?e:t<2/3?n+(e-n)*6*(2/3-t):n}class st{constructor(e,t,i){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(e,t,i)}set(e,t,i){if(t===void 0&&i===void 0){const r=e;r&&r.isColor?this.copy(r):typeof r=="number"?this.setHex(r):typeof r=="string"&&this.setStyle(r)}else this.setRGB(e,t,i);return this}setScalar(e){return this.r=e,this.g=e,this.b=e,this}setHex(e,t=wt){return e=Math.floor(e),this.r=(e>>16&255)/255,this.g=(e>>8&255)/255,this.b=(e&255)/255,gt.toWorkingColorSpace(this,t),this}setRGB(e,t,i,r=gt.workingColorSpace){return this.r=e,this.g=t,this.b=i,gt.toWorkingColorSpace(this,r),this}setHSL(e,t,i,r=gt.workingColorSpace){if(e=Uh(e,1),t=tn(t,0,1),i=tn(i,0,1),t===0)this.r=this.g=this.b=i;else{const s=i<=.5?i*(1+t):i+t-i*t,o=2*i-s;this.r=Sc(o,s,e+1/3),this.g=Sc(o,s,e),this.b=Sc(o,s,e-1/3)}return gt.toWorkingColorSpace(this,r),this}setStyle(e,t=wt){function i(s){s!==void 0&&parseFloat(s)<1&&console.warn("THREE.Color: Alpha component of "+e+" will be ignored.")}let r;if(r=/^(\w+)\(([^\)]*)\)/.exec(e)){let s;const o=r[1],a=r[2];switch(o){case"rgb":case"rgba":if(s=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(a))return i(s[4]),this.setRGB(Math.min(255,parseInt(s[1],10))/255,Math.min(255,parseInt(s[2],10))/255,Math.min(255,parseInt(s[3],10))/255,t);if(s=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(a))return i(s[4]),this.setRGB(Math.min(100,parseInt(s[1],10))/100,Math.min(100,parseInt(s[2],10))/100,Math.min(100,parseInt(s[3],10))/100,t);break;case"hsl":case"hsla":if(s=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(a))return i(s[4]),this.setHSL(parseFloat(s[1])/360,parseFloat(s[2])/100,parseFloat(s[3])/100,t);break;default:console.warn("THREE.Color: Unknown color model "+e)}}else if(r=/^\#([A-Fa-f\d]+)$/.exec(e)){const s=r[1],o=s.length;if(o===3)return this.setRGB(parseInt(s.charAt(0),16)/15,parseInt(s.charAt(1),16)/15,parseInt(s.charAt(2),16)/15,t);if(o===6)return this.setHex(parseInt(s,16),t);console.warn("THREE.Color: Invalid hex color "+e)}else if(e&&e.length>0)return this.setColorName(e,t);return this}setColorName(e,t=wt){const i=$0[e.toLowerCase()];return i!==void 0?this.setHex(i,t):console.warn("THREE.Color: Unknown color "+e),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(e){return this.r=e.r,this.g=e.g,this.b=e.b,this}copySRGBToLinear(e){return this.r=$s(e.r),this.g=$s(e.g),this.b=$s(e.b),this}copyLinearToSRGB(e){return this.r=sc(e.r),this.g=sc(e.g),this.b=sc(e.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(e=wt){return gt.fromWorkingColorSpace(cn.copy(this),e),Math.round(tn(cn.r*255,0,255))*65536+Math.round(tn(cn.g*255,0,255))*256+Math.round(tn(cn.b*255,0,255))}getHexString(e=wt){return("000000"+this.getHex(e).toString(16)).slice(-6)}getHSL(e,t=gt.workingColorSpace){gt.fromWorkingColorSpace(cn.copy(this),t);const i=cn.r,r=cn.g,s=cn.b,o=Math.max(i,r,s),a=Math.min(i,r,s);let l,c;const u=(a+o)/2;if(a===o)l=0,c=0;else{const h=o-a;switch(c=u<=.5?h/(o+a):h/(2-o-a),o){case i:l=(r-s)/h+(r<s?6:0);break;case r:l=(s-i)/h+2;break;case s:l=(i-r)/h+4;break}l/=6}return e.h=l,e.s=c,e.l=u,e}getRGB(e,t=gt.workingColorSpace){return gt.fromWorkingColorSpace(cn.copy(this),t),e.r=cn.r,e.g=cn.g,e.b=cn.b,e}getStyle(e=wt){gt.fromWorkingColorSpace(cn.copy(this),e);const t=cn.r,i=cn.g,r=cn.b;return e!==wt?`color(${e} ${t.toFixed(3)} ${i.toFixed(3)} ${r.toFixed(3)})`:`rgb(${Math.round(t*255)},${Math.round(i*255)},${Math.round(r*255)})`}offsetHSL(e,t,i){return this.getHSL(Zi),this.setHSL(Zi.h+e,Zi.s+t,Zi.l+i)}add(e){return this.r+=e.r,this.g+=e.g,this.b+=e.b,this}addColors(e,t){return this.r=e.r+t.r,this.g=e.g+t.g,this.b=e.b+t.b,this}addScalar(e){return this.r+=e,this.g+=e,this.b+=e,this}sub(e){return this.r=Math.max(0,this.r-e.r),this.g=Math.max(0,this.g-e.g),this.b=Math.max(0,this.b-e.b),this}multiply(e){return this.r*=e.r,this.g*=e.g,this.b*=e.b,this}multiplyScalar(e){return this.r*=e,this.g*=e,this.b*=e,this}lerp(e,t){return this.r+=(e.r-this.r)*t,this.g+=(e.g-this.g)*t,this.b+=(e.b-this.b)*t,this}lerpColors(e,t,i){return this.r=e.r+(t.r-e.r)*i,this.g=e.g+(t.g-e.g)*i,this.b=e.b+(t.b-e.b)*i,this}lerpHSL(e,t){this.getHSL(Zi),e.getHSL(Ea);const i=zo(Zi.h,Ea.h,t),r=zo(Zi.s,Ea.s,t),s=zo(Zi.l,Ea.l,t);return this.setHSL(i,r,s),this}setFromVector3(e){return this.r=e.x,this.g=e.y,this.b=e.z,this}applyMatrix3(e){const t=this.r,i=this.g,r=this.b,s=e.elements;return this.r=s[0]*t+s[3]*i+s[6]*r,this.g=s[1]*t+s[4]*i+s[7]*r,this.b=s[2]*t+s[5]*i+s[8]*r,this}equals(e){return e.r===this.r&&e.g===this.g&&e.b===this.b}fromArray(e,t=0){return this.r=e[t],this.g=e[t+1],this.b=e[t+2],this}toArray(e=[],t=0){return e[t]=this.r,e[t+1]=this.g,e[t+2]=this.b,e}fromBufferAttribute(e,t){return this.r=e.getX(t),this.g=e.getY(t),this.b=e.getZ(t),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}}const cn=new st;st.NAMES=$0;let Qg=0;class os extends Wi{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:Qg++}),this.uuid=ss(),this.name="",this.type="Material",this.blending=Ws,this.side=zi,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=fu,this.blendDst=du,this.blendEquation=zr,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new st(0,0,0),this.blendAlpha=0,this.depthFunc=Js,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=Tf,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=fs,this.stencilZFail=fs,this.stencilZPass=fs,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(e){this._alphaTest>0!=e>0&&this.version++,this._alphaTest=e}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(e){if(e!==void 0)for(const t in e){const i=e[t];if(i===void 0){console.warn(`THREE.Material: parameter '${t}' has value of undefined.`);continue}const r=this[t];if(r===void 0){console.warn(`THREE.Material: '${t}' is not a property of THREE.${this.type}.`);continue}r&&r.isColor?r.set(i):r&&r.isVector3&&i&&i.isVector3?r.copy(i):this[t]=i}}toJSON(e){const t=e===void 0||typeof e=="string";t&&(e={textures:{},images:{}});const i={metadata:{version:4.6,type:"Material",generator:"Material.toJSON"}};i.uuid=this.uuid,i.type=this.type,this.name!==""&&(i.name=this.name),this.color&&this.color.isColor&&(i.color=this.color.getHex()),this.roughness!==void 0&&(i.roughness=this.roughness),this.metalness!==void 0&&(i.metalness=this.metalness),this.sheen!==void 0&&(i.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(i.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(i.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(i.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&this.emissiveIntensity!==1&&(i.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(i.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(i.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(i.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(i.shininess=this.shininess),this.clearcoat!==void 0&&(i.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(i.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(i.clearcoatMap=this.clearcoatMap.toJSON(e).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(i.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(e).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(i.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(e).uuid,i.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.dispersion!==void 0&&(i.dispersion=this.dispersion),this.iridescence!==void 0&&(i.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(i.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(i.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(i.iridescenceMap=this.iridescenceMap.toJSON(e).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(i.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(e).uuid),this.anisotropy!==void 0&&(i.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(i.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(i.anisotropyMap=this.anisotropyMap.toJSON(e).uuid),this.map&&this.map.isTexture&&(i.map=this.map.toJSON(e).uuid),this.matcap&&this.matcap.isTexture&&(i.matcap=this.matcap.toJSON(e).uuid),this.alphaMap&&this.alphaMap.isTexture&&(i.alphaMap=this.alphaMap.toJSON(e).uuid),this.lightMap&&this.lightMap.isTexture&&(i.lightMap=this.lightMap.toJSON(e).uuid,i.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(i.aoMap=this.aoMap.toJSON(e).uuid,i.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(i.bumpMap=this.bumpMap.toJSON(e).uuid,i.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(i.normalMap=this.normalMap.toJSON(e).uuid,i.normalMapType=this.normalMapType,i.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(i.displacementMap=this.displacementMap.toJSON(e).uuid,i.displacementScale=this.displacementScale,i.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(i.roughnessMap=this.roughnessMap.toJSON(e).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(i.metalnessMap=this.metalnessMap.toJSON(e).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(i.emissiveMap=this.emissiveMap.toJSON(e).uuid),this.specularMap&&this.specularMap.isTexture&&(i.specularMap=this.specularMap.toJSON(e).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(i.specularIntensityMap=this.specularIntensityMap.toJSON(e).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(i.specularColorMap=this.specularColorMap.toJSON(e).uuid),this.envMap&&this.envMap.isTexture&&(i.envMap=this.envMap.toJSON(e).uuid,this.combine!==void 0&&(i.combine=this.combine)),this.envMapRotation!==void 0&&(i.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(i.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(i.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(i.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(i.gradientMap=this.gradientMap.toJSON(e).uuid),this.transmission!==void 0&&(i.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(i.transmissionMap=this.transmissionMap.toJSON(e).uuid),this.thickness!==void 0&&(i.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(i.thicknessMap=this.thicknessMap.toJSON(e).uuid),this.attenuationDistance!==void 0&&this.attenuationDistance!==1/0&&(i.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(i.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(i.size=this.size),this.shadowSide!==null&&(i.shadowSide=this.shadowSide),this.sizeAttenuation!==void 0&&(i.sizeAttenuation=this.sizeAttenuation),this.blending!==Ws&&(i.blending=this.blending),this.side!==zi&&(i.side=this.side),this.vertexColors===!0&&(i.vertexColors=!0),this.opacity<1&&(i.opacity=this.opacity),this.transparent===!0&&(i.transparent=!0),this.blendSrc!==fu&&(i.blendSrc=this.blendSrc),this.blendDst!==du&&(i.blendDst=this.blendDst),this.blendEquation!==zr&&(i.blendEquation=this.blendEquation),this.blendSrcAlpha!==null&&(i.blendSrcAlpha=this.blendSrcAlpha),this.blendDstAlpha!==null&&(i.blendDstAlpha=this.blendDstAlpha),this.blendEquationAlpha!==null&&(i.blendEquationAlpha=this.blendEquationAlpha),this.blendColor&&this.blendColor.isColor&&(i.blendColor=this.blendColor.getHex()),this.blendAlpha!==0&&(i.blendAlpha=this.blendAlpha),this.depthFunc!==Js&&(i.depthFunc=this.depthFunc),this.depthTest===!1&&(i.depthTest=this.depthTest),this.depthWrite===!1&&(i.depthWrite=this.depthWrite),this.colorWrite===!1&&(i.colorWrite=this.colorWrite),this.stencilWriteMask!==255&&(i.stencilWriteMask=this.stencilWriteMask),this.stencilFunc!==Tf&&(i.stencilFunc=this.stencilFunc),this.stencilRef!==0&&(i.stencilRef=this.stencilRef),this.stencilFuncMask!==255&&(i.stencilFuncMask=this.stencilFuncMask),this.stencilFail!==fs&&(i.stencilFail=this.stencilFail),this.stencilZFail!==fs&&(i.stencilZFail=this.stencilZFail),this.stencilZPass!==fs&&(i.stencilZPass=this.stencilZPass),this.stencilWrite===!0&&(i.stencilWrite=this.stencilWrite),this.rotation!==void 0&&this.rotation!==0&&(i.rotation=this.rotation),this.polygonOffset===!0&&(i.polygonOffset=!0),this.polygonOffsetFactor!==0&&(i.polygonOffsetFactor=this.polygonOffsetFactor),this.polygonOffsetUnits!==0&&(i.polygonOffsetUnits=this.polygonOffsetUnits),this.linewidth!==void 0&&this.linewidth!==1&&(i.linewidth=this.linewidth),this.dashSize!==void 0&&(i.dashSize=this.dashSize),this.gapSize!==void 0&&(i.gapSize=this.gapSize),this.scale!==void 0&&(i.scale=this.scale),this.dithering===!0&&(i.dithering=!0),this.alphaTest>0&&(i.alphaTest=this.alphaTest),this.alphaHash===!0&&(i.alphaHash=!0),this.alphaToCoverage===!0&&(i.alphaToCoverage=!0),this.premultipliedAlpha===!0&&(i.premultipliedAlpha=!0),this.forceSinglePass===!0&&(i.forceSinglePass=!0),this.wireframe===!0&&(i.wireframe=!0),this.wireframeLinewidth>1&&(i.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!=="round"&&(i.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!=="round"&&(i.wireframeLinejoin=this.wireframeLinejoin),this.flatShading===!0&&(i.flatShading=!0),this.visible===!1&&(i.visible=!1),this.toneMapped===!1&&(i.toneMapped=!1),this.fog===!1&&(i.fog=!1),Object.keys(this.userData).length>0&&(i.userData=this.userData);function r(s){const o=[];for(const a in s){const l=s[a];delete l.metadata,o.push(l)}return o}if(t){const s=r(e.textures),o=r(e.images);s.length>0&&(i.textures=s),o.length>0&&(i.images=o)}return i}clone(){return new this.constructor().copy(this)}copy(e){this.name=e.name,this.blending=e.blending,this.side=e.side,this.vertexColors=e.vertexColors,this.opacity=e.opacity,this.transparent=e.transparent,this.blendSrc=e.blendSrc,this.blendDst=e.blendDst,this.blendEquation=e.blendEquation,this.blendSrcAlpha=e.blendSrcAlpha,this.blendDstAlpha=e.blendDstAlpha,this.blendEquationAlpha=e.blendEquationAlpha,this.blendColor.copy(e.blendColor),this.blendAlpha=e.blendAlpha,this.depthFunc=e.depthFunc,this.depthTest=e.depthTest,this.depthWrite=e.depthWrite,this.stencilWriteMask=e.stencilWriteMask,this.stencilFunc=e.stencilFunc,this.stencilRef=e.stencilRef,this.stencilFuncMask=e.stencilFuncMask,this.stencilFail=e.stencilFail,this.stencilZFail=e.stencilZFail,this.stencilZPass=e.stencilZPass,this.stencilWrite=e.stencilWrite;const t=e.clippingPlanes;let i=null;if(t!==null){const r=t.length;i=new Array(r);for(let s=0;s!==r;++s)i[s]=t[s].clone()}return this.clippingPlanes=i,this.clipIntersection=e.clipIntersection,this.clipShadows=e.clipShadows,this.shadowSide=e.shadowSide,this.colorWrite=e.colorWrite,this.precision=e.precision,this.polygonOffset=e.polygonOffset,this.polygonOffsetFactor=e.polygonOffsetFactor,this.polygonOffsetUnits=e.polygonOffsetUnits,this.dithering=e.dithering,this.alphaTest=e.alphaTest,this.alphaHash=e.alphaHash,this.alphaToCoverage=e.alphaToCoverage,this.premultipliedAlpha=e.premultipliedAlpha,this.forceSinglePass=e.forceSinglePass,this.visible=e.visible,this.toneMapped=e.toneMapped,this.userData=JSON.parse(JSON.stringify(e.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(e){e===!0&&this.version++}onBuild(){console.warn("Material: onBuild() has been removed.")}}class Y0 extends os{constructor(e){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new st(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Mi,this.combine=P0,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.specularMap=e.specularMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.combine=e.combine,this.reflectivity=e.reflectivity,this.refractionRatio=e.refractionRatio,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.fog=e.fog,this}}const Xt=new O,Ta=new we;class kt{constructor(e,t,i=!1){if(Array.isArray(e))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,this.name="",this.array=e,this.itemSize=t,this.count=e!==void 0?e.length/t:0,this.normalized=i,this.usage=Af,this.updateRanges=[],this.gpuType=_i,this.version=0}onUploadCallback(){}set needsUpdate(e){e===!0&&this.version++}setUsage(e){return this.usage=e,this}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}copy(e){return this.name=e.name,this.array=new e.array.constructor(e.array),this.itemSize=e.itemSize,this.count=e.count,this.normalized=e.normalized,this.usage=e.usage,this.gpuType=e.gpuType,this}copyAt(e,t,i){e*=this.itemSize,i*=t.itemSize;for(let r=0,s=this.itemSize;r<s;r++)this.array[e+r]=t.array[i+r];return this}copyArray(e){return this.array.set(e),this}applyMatrix3(e){if(this.itemSize===2)for(let t=0,i=this.count;t<i;t++)Ta.fromBufferAttribute(this,t),Ta.applyMatrix3(e),this.setXY(t,Ta.x,Ta.y);else if(this.itemSize===3)for(let t=0,i=this.count;t<i;t++)Xt.fromBufferAttribute(this,t),Xt.applyMatrix3(e),this.setXYZ(t,Xt.x,Xt.y,Xt.z);return this}applyMatrix4(e){for(let t=0,i=this.count;t<i;t++)Xt.fromBufferAttribute(this,t),Xt.applyMatrix4(e),this.setXYZ(t,Xt.x,Xt.y,Xt.z);return this}applyNormalMatrix(e){for(let t=0,i=this.count;t<i;t++)Xt.fromBufferAttribute(this,t),Xt.applyNormalMatrix(e),this.setXYZ(t,Xt.x,Xt.y,Xt.z);return this}transformDirection(e){for(let t=0,i=this.count;t<i;t++)Xt.fromBufferAttribute(this,t),Xt.transformDirection(e),this.setXYZ(t,Xt.x,Xt.y,Xt.z);return this}set(e,t=0){return this.array.set(e,t),this}getComponent(e,t){let i=this.array[e*this.itemSize+t];return this.normalized&&(i=Us(i,this.array)),i}setComponent(e,t,i){return this.normalized&&(i=vn(i,this.array)),this.array[e*this.itemSize+t]=i,this}getX(e){let t=this.array[e*this.itemSize];return this.normalized&&(t=Us(t,this.array)),t}setX(e,t){return this.normalized&&(t=vn(t,this.array)),this.array[e*this.itemSize]=t,this}getY(e){let t=this.array[e*this.itemSize+1];return this.normalized&&(t=Us(t,this.array)),t}setY(e,t){return this.normalized&&(t=vn(t,this.array)),this.array[e*this.itemSize+1]=t,this}getZ(e){let t=this.array[e*this.itemSize+2];return this.normalized&&(t=Us(t,this.array)),t}setZ(e,t){return this.normalized&&(t=vn(t,this.array)),this.array[e*this.itemSize+2]=t,this}getW(e){let t=this.array[e*this.itemSize+3];return this.normalized&&(t=Us(t,this.array)),t}setW(e,t){return this.normalized&&(t=vn(t,this.array)),this.array[e*this.itemSize+3]=t,this}setXY(e,t,i){return e*=this.itemSize,this.normalized&&(t=vn(t,this.array),i=vn(i,this.array)),this.array[e+0]=t,this.array[e+1]=i,this}setXYZ(e,t,i,r){return e*=this.itemSize,this.normalized&&(t=vn(t,this.array),i=vn(i,this.array),r=vn(r,this.array)),this.array[e+0]=t,this.array[e+1]=i,this.array[e+2]=r,this}setXYZW(e,t,i,r,s){return e*=this.itemSize,this.normalized&&(t=vn(t,this.array),i=vn(i,this.array),r=vn(r,this.array),s=vn(s,this.array)),this.array[e+0]=t,this.array[e+1]=i,this.array[e+2]=r,this.array[e+3]=s,this}onUpload(e){return this.onUploadCallback=e,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){const e={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return this.name!==""&&(e.name=this.name),this.usage!==Af&&(e.usage=this.usage),e}}class Xl extends kt{constructor(e,t,i){super(new Uint16Array(e),t,i)}}class ql extends kt{constructor(e,t,i){super(new Uint32Array(e),t,i)}}class nt extends kt{constructor(e,t,i){super(new Float32Array(e),t,i)}}let ev=0;const $n=new It,Mc=new yn,Ms=new O,Un=new fa,Eo=new fa,Qt=new O;class Et extends Wi{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:ev++}),this.uuid=ss(),this.name="",this.type="BufferGeometry",this.index=null,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={}}getIndex(){return this.index}setIndex(e){return Array.isArray(e)?this.index=new(V0(e)?ql:Xl)(e,1):this.index=e,this}getAttribute(e){return this.attributes[e]}setAttribute(e,t){return this.attributes[e]=t,this}deleteAttribute(e){return delete this.attributes[e],this}hasAttribute(e){return this.attributes[e]!==void 0}addGroup(e,t,i=0){this.groups.push({start:e,count:t,materialIndex:i})}clearGroups(){this.groups=[]}setDrawRange(e,t){this.drawRange.start=e,this.drawRange.count=t}applyMatrix4(e){const t=this.attributes.position;t!==void 0&&(t.applyMatrix4(e),t.needsUpdate=!0);const i=this.attributes.normal;if(i!==void 0){const s=new tt().getNormalMatrix(e);i.applyNormalMatrix(s),i.needsUpdate=!0}const r=this.attributes.tangent;return r!==void 0&&(r.transformDirection(e),r.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this}applyQuaternion(e){return $n.makeRotationFromQuaternion(e),this.applyMatrix4($n),this}rotateX(e){return $n.makeRotationX(e),this.applyMatrix4($n),this}rotateY(e){return $n.makeRotationY(e),this.applyMatrix4($n),this}rotateZ(e){return $n.makeRotationZ(e),this.applyMatrix4($n),this}translate(e,t,i){return $n.makeTranslation(e,t,i),this.applyMatrix4($n),this}scale(e,t,i){return $n.makeScale(e,t,i),this.applyMatrix4($n),this}lookAt(e){return Mc.lookAt(e),Mc.updateMatrix(),this.applyMatrix4(Mc.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(Ms).negate(),this.translate(Ms.x,Ms.y,Ms.z),this}setFromPoints(e){const t=[];for(let i=0,r=e.length;i<r;i++){const s=e[i];t.push(s.x,s.y,s.z||0)}return this.setAttribute("position",new nt(t,3)),this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new fa);const e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new O(-1/0,-1/0,-1/0),new O(1/0,1/0,1/0));return}if(e!==void 0){if(this.boundingBox.setFromBufferAttribute(e),t)for(let i=0,r=t.length;i<r;i++){const s=t[i];Un.setFromBufferAttribute(s),this.morphTargetsRelative?(Qt.addVectors(this.boundingBox.min,Un.min),this.boundingBox.expandByPoint(Qt),Qt.addVectors(this.boundingBox.max,Un.max),this.boundingBox.expandByPoint(Qt)):(this.boundingBox.expandByPoint(Un.min),this.boundingBox.expandByPoint(Un.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&console.error('THREE.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new Wl);const e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){console.error("THREE.BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new O,1/0);return}if(e){const i=this.boundingSphere.center;if(Un.setFromBufferAttribute(e),t)for(let s=0,o=t.length;s<o;s++){const a=t[s];Eo.setFromBufferAttribute(a),this.morphTargetsRelative?(Qt.addVectors(Un.min,Eo.min),Un.expandByPoint(Qt),Qt.addVectors(Un.max,Eo.max),Un.expandByPoint(Qt)):(Un.expandByPoint(Eo.min),Un.expandByPoint(Eo.max))}Un.getCenter(i);let r=0;for(let s=0,o=e.count;s<o;s++)Qt.fromBufferAttribute(e,s),r=Math.max(r,i.distanceToSquared(Qt));if(t)for(let s=0,o=t.length;s<o;s++){const a=t[s],l=this.morphTargetsRelative;for(let c=0,u=a.count;c<u;c++)Qt.fromBufferAttribute(a,c),l&&(Ms.fromBufferAttribute(e,c),Qt.add(Ms)),r=Math.max(r,i.distanceToSquared(Qt))}this.boundingSphere.radius=Math.sqrt(r),isNaN(this.boundingSphere.radius)&&console.error('THREE.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){const e=this.index,t=this.attributes;if(e===null||t.position===void 0||t.normal===void 0||t.uv===void 0){console.error("THREE.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}const i=t.position,r=t.normal,s=t.uv;this.hasAttribute("tangent")===!1&&this.setAttribute("tangent",new kt(new Float32Array(4*i.count),4));const o=this.getAttribute("tangent"),a=[],l=[];for(let P=0;P<i.count;P++)a[P]=new O,l[P]=new O;const c=new O,u=new O,h=new O,f=new we,d=new we,v=new we,g=new O,p=new O;function m(P,I,S){c.fromBufferAttribute(i,P),u.fromBufferAttribute(i,I),h.fromBufferAttribute(i,S),f.fromBufferAttribute(s,P),d.fromBufferAttribute(s,I),v.fromBufferAttribute(s,S),u.sub(c),h.sub(c),d.sub(f),v.sub(f);const b=1/(d.x*v.y-v.x*d.y);isFinite(b)&&(g.copy(u).multiplyScalar(v.y).addScaledVector(h,-d.y).multiplyScalar(b),p.copy(h).multiplyScalar(d.x).addScaledVector(u,-v.x).multiplyScalar(b),a[P].add(g),a[I].add(g),a[S].add(g),l[P].add(p),l[I].add(p),l[S].add(p))}let x=this.groups;x.length===0&&(x=[{start:0,count:e.count}]);for(let P=0,I=x.length;P<I;++P){const S=x[P],b=S.start,N=S.count;for(let R=b,H=b+N;R<H;R+=3)m(e.getX(R+0),e.getX(R+1),e.getX(R+2))}const _=new O,y=new O,C=new O,M=new O;function w(P){C.fromBufferAttribute(r,P),M.copy(C);const I=a[P];_.copy(I),_.sub(C.multiplyScalar(C.dot(I))).normalize(),y.crossVectors(M,I);const b=y.dot(l[P])<0?-1:1;o.setXYZW(P,_.x,_.y,_.z,b)}for(let P=0,I=x.length;P<I;++P){const S=x[P],b=S.start,N=S.count;for(let R=b,H=b+N;R<H;R+=3)w(e.getX(R+0)),w(e.getX(R+1)),w(e.getX(R+2))}}computeVertexNormals(){const e=this.index,t=this.getAttribute("position");if(t!==void 0){let i=this.getAttribute("normal");if(i===void 0)i=new kt(new Float32Array(t.count*3),3),this.setAttribute("normal",i);else for(let f=0,d=i.count;f<d;f++)i.setXYZ(f,0,0,0);const r=new O,s=new O,o=new O,a=new O,l=new O,c=new O,u=new O,h=new O;if(e)for(let f=0,d=e.count;f<d;f+=3){const v=e.getX(f+0),g=e.getX(f+1),p=e.getX(f+2);r.fromBufferAttribute(t,v),s.fromBufferAttribute(t,g),o.fromBufferAttribute(t,p),u.subVectors(o,s),h.subVectors(r,s),u.cross(h),a.fromBufferAttribute(i,v),l.fromBufferAttribute(i,g),c.fromBufferAttribute(i,p),a.add(u),l.add(u),c.add(u),i.setXYZ(v,a.x,a.y,a.z),i.setXYZ(g,l.x,l.y,l.z),i.setXYZ(p,c.x,c.y,c.z)}else for(let f=0,d=t.count;f<d;f+=3)r.fromBufferAttribute(t,f+0),s.fromBufferAttribute(t,f+1),o.fromBufferAttribute(t,f+2),u.subVectors(o,s),h.subVectors(r,s),u.cross(h),i.setXYZ(f+0,u.x,u.y,u.z),i.setXYZ(f+1,u.x,u.y,u.z),i.setXYZ(f+2,u.x,u.y,u.z);this.normalizeNormals(),i.needsUpdate=!0}}normalizeNormals(){const e=this.attributes.normal;for(let t=0,i=e.count;t<i;t++)Qt.fromBufferAttribute(e,t),Qt.normalize(),e.setXYZ(t,Qt.x,Qt.y,Qt.z)}toNonIndexed(){function e(a,l){const c=a.array,u=a.itemSize,h=a.normalized,f=new c.constructor(l.length*u);let d=0,v=0;for(let g=0,p=l.length;g<p;g++){a.isInterleavedBufferAttribute?d=l[g]*a.data.stride+a.offset:d=l[g]*u;for(let m=0;m<u;m++)f[v++]=c[d++]}return new kt(f,u,h)}if(this.index===null)return console.warn("THREE.BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;const t=new Et,i=this.index.array,r=this.attributes;for(const a in r){const l=r[a],c=e(l,i);t.setAttribute(a,c)}const s=this.morphAttributes;for(const a in s){const l=[],c=s[a];for(let u=0,h=c.length;u<h;u++){const f=c[u],d=e(f,i);l.push(d)}t.morphAttributes[a]=l}t.morphTargetsRelative=this.morphTargetsRelative;const o=this.groups;for(let a=0,l=o.length;a<l;a++){const c=o[a];t.addGroup(c.start,c.count,c.materialIndex)}return t}toJSON(){const e={metadata:{version:4.6,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(e.uuid=this.uuid,e.type=this.type,this.name!==""&&(e.name=this.name),Object.keys(this.userData).length>0&&(e.userData=this.userData),this.parameters!==void 0){const l=this.parameters;for(const c in l)l[c]!==void 0&&(e[c]=l[c]);return e}e.data={attributes:{}};const t=this.index;t!==null&&(e.data.index={type:t.array.constructor.name,array:Array.prototype.slice.call(t.array)});const i=this.attributes;for(const l in i){const c=i[l];e.data.attributes[l]=c.toJSON(e.data)}const r={};let s=!1;for(const l in this.morphAttributes){const c=this.morphAttributes[l],u=[];for(let h=0,f=c.length;h<f;h++){const d=c[h];u.push(d.toJSON(e.data))}u.length>0&&(r[l]=u,s=!0)}s&&(e.data.morphAttributes=r,e.data.morphTargetsRelative=this.morphTargetsRelative);const o=this.groups;o.length>0&&(e.data.groups=JSON.parse(JSON.stringify(o)));const a=this.boundingSphere;return a!==null&&(e.data.boundingSphere={center:a.center.toArray(),radius:a.radius}),e}clone(){return new this.constructor().copy(this)}copy(e){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;const t={};this.name=e.name;const i=e.index;i!==null&&this.setIndex(i.clone(t));const r=e.attributes;for(const c in r){const u=r[c];this.setAttribute(c,u.clone(t))}const s=e.morphAttributes;for(const c in s){const u=[],h=s[c];for(let f=0,d=h.length;f<d;f++)u.push(h[f].clone(t));this.morphAttributes[c]=u}this.morphTargetsRelative=e.morphTargetsRelative;const o=e.groups;for(let c=0,u=o.length;c<u;c++){const h=o[c];this.addGroup(h.start,h.count,h.materialIndex)}const a=e.boundingBox;a!==null&&(this.boundingBox=a.clone());const l=e.boundingSphere;return l!==null&&(this.boundingSphere=l.clone()),this.drawRange.start=e.drawRange.start,this.drawRange.count=e.drawRange.count,this.userData=e.userData,this}dispose(){this.dispatchEvent({type:"dispose"})}}const Gf=new It,Pr=new X0,Aa=new Wl,Vf=new O,Ca=new O,Ra=new O,Pa=new O,bc=new O,La=new O,Wf=new O,Da=new O;class Gt extends yn{constructor(e=new Et,t=new Y0){super(),this.isMesh=!0,this.type="Mesh",this.geometry=e,this.material=t,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),e.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=e.morphTargetInfluences.slice()),e.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},e.morphTargetDictionary)),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}updateMorphTargets(){const t=this.geometry.morphAttributes,i=Object.keys(t);if(i.length>0){const r=t[i[0]];if(r!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let s=0,o=r.length;s<o;s++){const a=r[s].name||String(s);this.morphTargetInfluences.push(0),this.morphTargetDictionary[a]=s}}}}getVertexPosition(e,t){const i=this.geometry,r=i.attributes.position,s=i.morphAttributes.position,o=i.morphTargetsRelative;t.fromBufferAttribute(r,e);const a=this.morphTargetInfluences;if(s&&a){La.set(0,0,0);for(let l=0,c=s.length;l<c;l++){const u=a[l],h=s[l];u!==0&&(bc.fromBufferAttribute(h,e),o?La.addScaledVector(bc,u):La.addScaledVector(bc.sub(t),u))}t.add(La)}return t}raycast(e,t){const i=this.geometry,r=this.material,s=this.matrixWorld;r!==void 0&&(i.boundingSphere===null&&i.computeBoundingSphere(),Aa.copy(i.boundingSphere),Aa.applyMatrix4(s),Pr.copy(e.ray).recast(e.near),!(Aa.containsPoint(Pr.origin)===!1&&(Pr.intersectSphere(Aa,Vf)===null||Pr.origin.distanceToSquared(Vf)>(e.far-e.near)**2))&&(Gf.copy(s).invert(),Pr.copy(e.ray).applyMatrix4(Gf),!(i.boundingBox!==null&&Pr.intersectsBox(i.boundingBox)===!1)&&this._computeIntersections(e,t,Pr)))}_computeIntersections(e,t,i){let r;const s=this.geometry,o=this.material,a=s.index,l=s.attributes.position,c=s.attributes.uv,u=s.attributes.uv1,h=s.attributes.normal,f=s.groups,d=s.drawRange;if(a!==null)if(Array.isArray(o))for(let v=0,g=f.length;v<g;v++){const p=f[v],m=o[p.materialIndex],x=Math.max(p.start,d.start),_=Math.min(a.count,Math.min(p.start+p.count,d.start+d.count));for(let y=x,C=_;y<C;y+=3){const M=a.getX(y),w=a.getX(y+1),P=a.getX(y+2);r=Ia(this,m,e,i,c,u,h,M,w,P),r&&(r.faceIndex=Math.floor(y/3),r.face.materialIndex=p.materialIndex,t.push(r))}}else{const v=Math.max(0,d.start),g=Math.min(a.count,d.start+d.count);for(let p=v,m=g;p<m;p+=3){const x=a.getX(p),_=a.getX(p+1),y=a.getX(p+2);r=Ia(this,o,e,i,c,u,h,x,_,y),r&&(r.faceIndex=Math.floor(p/3),t.push(r))}}else if(l!==void 0)if(Array.isArray(o))for(let v=0,g=f.length;v<g;v++){const p=f[v],m=o[p.materialIndex],x=Math.max(p.start,d.start),_=Math.min(l.count,Math.min(p.start+p.count,d.start+d.count));for(let y=x,C=_;y<C;y+=3){const M=y,w=y+1,P=y+2;r=Ia(this,m,e,i,c,u,h,M,w,P),r&&(r.faceIndex=Math.floor(y/3),r.face.materialIndex=p.materialIndex,t.push(r))}}else{const v=Math.max(0,d.start),g=Math.min(l.count,d.start+d.count);for(let p=v,m=g;p<m;p+=3){const x=p,_=p+1,y=p+2;r=Ia(this,o,e,i,c,u,h,x,_,y),r&&(r.faceIndex=Math.floor(p/3),t.push(r))}}}}function tv(n,e,t,i,r,s,o,a){let l;if(e.side===Kt?l=i.intersectTriangle(o,s,r,!0,a):l=i.intersectTriangle(r,s,o,e.side===zi,a),l===null)return null;Da.copy(a),Da.applyMatrix4(n.matrixWorld);const c=t.ray.origin.distanceTo(Da);return c<t.near||c>t.far?null:{distance:c,point:Da.clone(),object:n}}function Ia(n,e,t,i,r,s,o,a,l,c){n.getVertexPosition(a,Ca),n.getVertexPosition(l,Ra),n.getVertexPosition(c,Pa);const u=tv(n,e,t,i,Ca,Ra,Pa,Wf);if(u){const h=new O;Bn.getBarycoord(Wf,Ca,Ra,Pa,h),r&&(u.uv=Bn.getInterpolatedAttribute(r,a,l,c,h,new we)),s&&(u.uv1=Bn.getInterpolatedAttribute(s,a,l,c,h,new we)),o&&(u.normal=Bn.getInterpolatedAttribute(o,a,l,c,h,new O),u.normal.dot(i.direction)>0&&u.normal.multiplyScalar(-1));const f={a,b:l,c,normal:new O,materialIndex:0};Bn.getNormal(Ca,Ra,Pa,f.normal),u.face=f,u.barycoord=h}return u}class fo extends Et{constructor(e=1,t=1,i=1,r=1,s=1,o=1){super(),this.type="BoxGeometry",this.parameters={width:e,height:t,depth:i,widthSegments:r,heightSegments:s,depthSegments:o};const a=this;r=Math.floor(r),s=Math.floor(s),o=Math.floor(o);const l=[],c=[],u=[],h=[];let f=0,d=0;v("z","y","x",-1,-1,i,t,e,o,s,0),v("z","y","x",1,-1,i,t,-e,o,s,1),v("x","z","y",1,1,e,i,t,r,o,2),v("x","z","y",1,-1,e,i,-t,r,o,3),v("x","y","z",1,-1,e,t,i,r,s,4),v("x","y","z",-1,-1,e,t,-i,r,s,5),this.setIndex(l),this.setAttribute("position",new nt(c,3)),this.setAttribute("normal",new nt(u,3)),this.setAttribute("uv",new nt(h,2));function v(g,p,m,x,_,y,C,M,w,P,I){const S=y/w,b=C/P,N=y/2,R=C/2,H=M/2,T=w+1,k=P+1;let Z=0,K=0;const pe=new O;for(let ce=0;ce<k;ce++){const W=ce*b-R;for(let re=0;re<T;re++){const Ae=re*S-N;pe[g]=Ae*x,pe[p]=W*_,pe[m]=H,c.push(pe.x,pe.y,pe.z),pe[g]=0,pe[p]=0,pe[m]=M>0?1:-1,u.push(pe.x,pe.y,pe.z),h.push(re/w),h.push(1-ce/P),Z+=1}}for(let ce=0;ce<P;ce++)for(let W=0;W<w;W++){const re=f+W+T*ce,Ae=f+W+T*(ce+1),ee=f+(W+1)+T*(ce+1),F=f+(W+1)+T*ce;l.push(re,Ae,F),l.push(Ae,ee,F),K+=6}a.addGroup(d,K,I),d+=K,f+=Z}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new fo(e.width,e.height,e.depth,e.widthSegments,e.heightSegments,e.depthSegments)}}function to(n){const e={};for(const t in n){e[t]={};for(const i in n[t]){const r=n[t][i];r&&(r.isColor||r.isMatrix3||r.isMatrix4||r.isVector2||r.isVector3||r.isVector4||r.isTexture||r.isQuaternion)?r.isRenderTargetTexture?(console.warn("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),e[t][i]=null):e[t][i]=r.clone():Array.isArray(r)?e[t][i]=r.slice():e[t][i]=r}}return e}function _n(n){const e={};for(let t=0;t<n.length;t++){const i=to(n[t]);for(const r in i)e[r]=i[r]}return e}function nv(n){const e=[];for(let t=0;t<n.length;t++)e.push(n[t].clone());return e}function K0(n){const e=n.getRenderTarget();return e===null?n.outputColorSpace:e.isXRRenderTarget===!0?e.texture.colorSpace:gt.workingColorSpace}const iv={clone:to,merge:_n};var rv=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,sv=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`;class xt extends os{constructor(e){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=rv,this.fragmentShader=sv,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,e!==void 0&&this.setValues(e)}copy(e){return super.copy(e),this.fragmentShader=e.fragmentShader,this.vertexShader=e.vertexShader,this.uniforms=to(e.uniforms),this.uniformsGroups=nv(e.uniformsGroups),this.defines=Object.assign({},e.defines),this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.fog=e.fog,this.lights=e.lights,this.clipping=e.clipping,this.extensions=Object.assign({},e.extensions),this.glslVersion=e.glslVersion,this}toJSON(e){const t=super.toJSON(e);t.glslVersion=this.glslVersion,t.uniforms={};for(const r in this.uniforms){const o=this.uniforms[r].value;o&&o.isTexture?t.uniforms[r]={type:"t",value:o.toJSON(e).uuid}:o&&o.isColor?t.uniforms[r]={type:"c",value:o.getHex()}:o&&o.isVector2?t.uniforms[r]={type:"v2",value:o.toArray()}:o&&o.isVector3?t.uniforms[r]={type:"v3",value:o.toArray()}:o&&o.isVector4?t.uniforms[r]={type:"v4",value:o.toArray()}:o&&o.isMatrix3?t.uniforms[r]={type:"m3",value:o.toArray()}:o&&o.isMatrix4?t.uniforms[r]={type:"m4",value:o.toArray()}:t.uniforms[r]={value:o}}Object.keys(this.defines).length>0&&(t.defines=this.defines),t.vertexShader=this.vertexShader,t.fragmentShader=this.fragmentShader,t.lights=this.lights,t.clipping=this.clipping;const i={};for(const r in this.extensions)this.extensions[r]===!0&&(i[r]=!0);return Object.keys(i).length>0&&(t.extensions=i),t}}class Nh extends yn{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new It,this.projectionMatrix=new It,this.projectionMatrixInverse=new It,this.coordinateSystem=Oi}copy(e,t){return super.copy(e,t),this.matrixWorldInverse.copy(e.matrixWorldInverse),this.projectionMatrix.copy(e.projectionMatrix),this.projectionMatrixInverse.copy(e.projectionMatrixInverse),this.coordinateSystem=e.coordinateSystem,this}getWorldDirection(e){return super.getWorldDirection(e).negate()}updateMatrixWorld(e){super.updateMatrixWorld(e),this.matrixWorldInverse.copy(this.matrixWorld).invert()}updateWorldMatrix(e,t){super.updateWorldMatrix(e,t),this.matrixWorldInverse.copy(this.matrixWorld).invert()}clone(){return new this.constructor().copy(this)}}const Ji=new O,Xf=new we,qf=new we;class kn extends Nh{constructor(e=50,t=1,i=.1,r=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=e,this.zoom=1,this.near=i,this.far=r,this.focus=10,this.aspect=t,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.fov=e.fov,this.zoom=e.zoom,this.near=e.near,this.far=e.far,this.focus=e.focus,this.aspect=e.aspect,this.view=e.view===null?null:Object.assign({},e.view),this.filmGauge=e.filmGauge,this.filmOffset=e.filmOffset,this}setFocalLength(e){const t=.5*this.getFilmHeight()/e;this.fov=Zo*2*Math.atan(t),this.updateProjectionMatrix()}getFocalLength(){const e=Math.tan(qs*.5*this.fov);return .5*this.getFilmHeight()/e}getEffectiveFOV(){return Zo*2*Math.atan(Math.tan(qs*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(e,t,i){Ji.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),t.set(Ji.x,Ji.y).multiplyScalar(-e/Ji.z),Ji.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),i.set(Ji.x,Ji.y).multiplyScalar(-e/Ji.z)}getViewSize(e,t){return this.getViewBounds(e,Xf,qf),t.subVectors(qf,Xf)}setViewOffset(e,t,i,r,s,o){this.aspect=e/t,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=i,this.view.offsetY=r,this.view.width=s,this.view.height=o,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){const e=this.near;let t=e*Math.tan(qs*.5*this.fov)/this.zoom,i=2*t,r=this.aspect*i,s=-.5*r;const o=this.view;if(this.view!==null&&this.view.enabled){const l=o.fullWidth,c=o.fullHeight;s+=o.offsetX*r/l,t-=o.offsetY*i/c,r*=o.width/l,i*=o.height/c}const a=this.filmOffset;a!==0&&(s+=e*a/this.getFilmWidth()),this.projectionMatrix.makePerspective(s,s+r,t,t-i,e,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){const t=super.toJSON(e);return t.object.fov=this.fov,t.object.zoom=this.zoom,t.object.near=this.near,t.object.far=this.far,t.object.focus=this.focus,t.object.aspect=this.aspect,this.view!==null&&(t.object.view=Object.assign({},this.view)),t.object.filmGauge=this.filmGauge,t.object.filmOffset=this.filmOffset,t}}const bs=-90,ws=1;class ov extends yn{constructor(e,t,i){super(),this.type="CubeCamera",this.renderTarget=i,this.coordinateSystem=null,this.activeMipmapLevel=0;const r=new kn(bs,ws,e,t);r.layers=this.layers,this.add(r);const s=new kn(bs,ws,e,t);s.layers=this.layers,this.add(s);const o=new kn(bs,ws,e,t);o.layers=this.layers,this.add(o);const a=new kn(bs,ws,e,t);a.layers=this.layers,this.add(a);const l=new kn(bs,ws,e,t);l.layers=this.layers,this.add(l);const c=new kn(bs,ws,e,t);c.layers=this.layers,this.add(c)}updateCoordinateSystem(){const e=this.coordinateSystem,t=this.children.concat(),[i,r,s,o,a,l]=t;for(const c of t)this.remove(c);if(e===Oi)i.up.set(0,1,0),i.lookAt(1,0,0),r.up.set(0,1,0),r.lookAt(-1,0,0),s.up.set(0,0,-1),s.lookAt(0,1,0),o.up.set(0,0,1),o.lookAt(0,-1,0),a.up.set(0,1,0),a.lookAt(0,0,1),l.up.set(0,1,0),l.lookAt(0,0,-1);else if(e===bl)i.up.set(0,-1,0),i.lookAt(-1,0,0),r.up.set(0,-1,0),r.lookAt(1,0,0),s.up.set(0,0,1),s.lookAt(0,1,0),o.up.set(0,0,-1),o.lookAt(0,-1,0),a.up.set(0,-1,0),a.lookAt(0,0,1),l.up.set(0,-1,0),l.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+e);for(const c of t)this.add(c),c.updateMatrixWorld()}update(e,t){this.parent===null&&this.updateMatrixWorld();const{renderTarget:i,activeMipmapLevel:r}=this;this.coordinateSystem!==e.coordinateSystem&&(this.coordinateSystem=e.coordinateSystem,this.updateCoordinateSystem());const[s,o,a,l,c,u]=this.children,h=e.getRenderTarget(),f=e.getActiveCubeFace(),d=e.getActiveMipmapLevel(),v=e.xr.enabled;e.xr.enabled=!1;const g=i.texture.generateMipmaps;i.texture.generateMipmaps=!1,e.setRenderTarget(i,0,r),e.render(t,s),e.setRenderTarget(i,1,r),e.render(t,o),e.setRenderTarget(i,2,r),e.render(t,a),e.setRenderTarget(i,3,r),e.render(t,l),e.setRenderTarget(i,4,r),e.render(t,c),i.texture.generateMipmaps=g,e.setRenderTarget(i,5,r),e.render(t,u),e.setRenderTarget(h,f,d),e.xr.enabled=v,i.texture.needsPMREMUpdate=!0}}class j0 extends sn{constructor(e,t,i,r,s,o,a,l,c,u){e=e!==void 0?e:[],t=t!==void 0?t:Qs,super(e,t,i,r,s,o,a,l,c,u),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(e){this.image=e}}class av extends Sn{constructor(e=1,t={}){super(e,e,t),this.isWebGLCubeRenderTarget=!0;const i={width:e,height:e,depth:1},r=[i,i,i,i,i,i];this.texture=new j0(r,t.mapping,t.wrapS,t.wrapT,t.magFilter,t.minFilter,t.format,t.type,t.anisotropy,t.colorSpace),this.texture.isRenderTargetTexture=!0,this.texture.generateMipmaps=t.generateMipmaps!==void 0?t.generateMipmaps:!1,this.texture.minFilter=t.minFilter!==void 0?t.minFilter:hn}fromEquirectangularTexture(e,t){this.texture.type=t.type,this.texture.colorSpace=t.colorSpace,this.texture.generateMipmaps=t.generateMipmaps,this.texture.minFilter=t.minFilter,this.texture.magFilter=t.magFilter;const i={uniforms:{tEquirect:{value:null}},vertexShader:`

				varying vec3 vWorldDirection;

				vec3 transformDirection( in vec3 dir, in mat4 matrix ) {

					return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );

				}

				void main() {

					vWorldDirection = transformDirection( position, modelMatrix );

					#include <begin_vertex>
					#include <project_vertex>

				}
			`,fragmentShader:`

				uniform sampler2D tEquirect;

				varying vec3 vWorldDirection;

				#include <common>

				void main() {

					vec3 direction = normalize( vWorldDirection );

					vec2 sampleUV = equirectUv( direction );

					gl_FragColor = texture2D( tEquirect, sampleUV );

				}
			`},r=new fo(5,5,5),s=new xt({name:"CubemapFromEquirect",uniforms:to(i.uniforms),vertexShader:i.vertexShader,fragmentShader:i.fragmentShader,side:Kt,blending:An});s.uniforms.tEquirect.value=t;const o=new Gt(r,s),a=t.minFilter;return t.minFilter===lr&&(t.minFilter=hn),new ov(1,10,this).update(e,o),t.minFilter=a,o.geometry.dispose(),o.material.dispose(),this}clear(e,t,i,r){const s=e.getRenderTarget();for(let o=0;o<6;o++)e.setRenderTarget(this,o),e.clear(t,i,r);e.setRenderTarget(s)}}const wc=new O,lv=new O,cv=new tt;class Or{constructor(e=new O(1,0,0),t=0){this.isPlane=!0,this.normal=e,this.constant=t}set(e,t){return this.normal.copy(e),this.constant=t,this}setComponents(e,t,i,r){return this.normal.set(e,t,i),this.constant=r,this}setFromNormalAndCoplanarPoint(e,t){return this.normal.copy(e),this.constant=-t.dot(this.normal),this}setFromCoplanarPoints(e,t,i){const r=wc.subVectors(i,t).cross(lv.subVectors(e,t)).normalize();return this.setFromNormalAndCoplanarPoint(r,e),this}copy(e){return this.normal.copy(e.normal),this.constant=e.constant,this}normalize(){const e=1/this.normal.length();return this.normal.multiplyScalar(e),this.constant*=e,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(e){return this.normal.dot(e)+this.constant}distanceToSphere(e){return this.distanceToPoint(e.center)-e.radius}projectPoint(e,t){return t.copy(e).addScaledVector(this.normal,-this.distanceToPoint(e))}intersectLine(e,t){const i=e.delta(wc),r=this.normal.dot(i);if(r===0)return this.distanceToPoint(e.start)===0?t.copy(e.start):null;const s=-(e.start.dot(this.normal)+this.constant)/r;return s<0||s>1?null:t.copy(e.start).addScaledVector(i,s)}intersectsLine(e){const t=this.distanceToPoint(e.start),i=this.distanceToPoint(e.end);return t<0&&i>0||i<0&&t>0}intersectsBox(e){return e.intersectsPlane(this)}intersectsSphere(e){return e.intersectsPlane(this)}coplanarPoint(e){return e.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(e,t){const i=t||cv.getNormalMatrix(e),r=this.coplanarPoint(wc).applyMatrix4(e),s=this.normal.applyMatrix3(i).normalize();return this.constant=-r.dot(s),this}translate(e){return this.constant-=e.dot(this.normal),this}equals(e){return e.normal.equals(this.normal)&&e.constant===this.constant}clone(){return new this.constructor().copy(this)}}const Lr=new Wl,Ua=new O;class Z0{constructor(e=new Or,t=new Or,i=new Or,r=new Or,s=new Or,o=new Or){this.planes=[e,t,i,r,s,o]}set(e,t,i,r,s,o){const a=this.planes;return a[0].copy(e),a[1].copy(t),a[2].copy(i),a[3].copy(r),a[4].copy(s),a[5].copy(o),this}copy(e){const t=this.planes;for(let i=0;i<6;i++)t[i].copy(e.planes[i]);return this}setFromProjectionMatrix(e,t=Oi){const i=this.planes,r=e.elements,s=r[0],o=r[1],a=r[2],l=r[3],c=r[4],u=r[5],h=r[6],f=r[7],d=r[8],v=r[9],g=r[10],p=r[11],m=r[12],x=r[13],_=r[14],y=r[15];if(i[0].setComponents(l-s,f-c,p-d,y-m).normalize(),i[1].setComponents(l+s,f+c,p+d,y+m).normalize(),i[2].setComponents(l+o,f+u,p+v,y+x).normalize(),i[3].setComponents(l-o,f-u,p-v,y-x).normalize(),i[4].setComponents(l-a,f-h,p-g,y-_).normalize(),t===Oi)i[5].setComponents(l+a,f+h,p+g,y+_).normalize();else if(t===bl)i[5].setComponents(a,h,g,_).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+t);return this}intersectsObject(e){if(e.boundingSphere!==void 0)e.boundingSphere===null&&e.computeBoundingSphere(),Lr.copy(e.boundingSphere).applyMatrix4(e.matrixWorld);else{const t=e.geometry;t.boundingSphere===null&&t.computeBoundingSphere(),Lr.copy(t.boundingSphere).applyMatrix4(e.matrixWorld)}return this.intersectsSphere(Lr)}intersectsSprite(e){return Lr.center.set(0,0,0),Lr.radius=.7071067811865476,Lr.applyMatrix4(e.matrixWorld),this.intersectsSphere(Lr)}intersectsSphere(e){const t=this.planes,i=e.center,r=-e.radius;for(let s=0;s<6;s++)if(t[s].distanceToPoint(i)<r)return!1;return!0}intersectsBox(e){const t=this.planes;for(let i=0;i<6;i++){const r=t[i];if(Ua.x=r.normal.x>0?e.max.x:e.min.x,Ua.y=r.normal.y>0?e.max.y:e.min.y,Ua.z=r.normal.z>0?e.max.z:e.min.z,r.distanceToPoint(Ua)<0)return!1}return!0}containsPoint(e){const t=this.planes;for(let i=0;i<6;i++)if(t[i].distanceToPoint(e)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}}function J0(){let n=null,e=!1,t=null,i=null;function r(s,o){t(s,o),i=n.requestAnimationFrame(r)}return{start:function(){e!==!0&&t!==null&&(i=n.requestAnimationFrame(r),e=!0)},stop:function(){n.cancelAnimationFrame(i),e=!1},setAnimationLoop:function(s){t=s},setContext:function(s){n=s}}}function uv(n){const e=new WeakMap;function t(a,l){const c=a.array,u=a.usage,h=c.byteLength,f=n.createBuffer();n.bindBuffer(l,f),n.bufferData(l,c,u),a.onUploadCallback();let d;if(c instanceof Float32Array)d=n.FLOAT;else if(c instanceof Uint16Array)a.isFloat16BufferAttribute?d=n.HALF_FLOAT:d=n.UNSIGNED_SHORT;else if(c instanceof Int16Array)d=n.SHORT;else if(c instanceof Uint32Array)d=n.UNSIGNED_INT;else if(c instanceof Int32Array)d=n.INT;else if(c instanceof Int8Array)d=n.BYTE;else if(c instanceof Uint8Array)d=n.UNSIGNED_BYTE;else if(c instanceof Uint8ClampedArray)d=n.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+c);return{buffer:f,type:d,bytesPerElement:c.BYTES_PER_ELEMENT,version:a.version,size:h}}function i(a,l,c){const u=l.array,h=l.updateRanges;if(n.bindBuffer(c,a),h.length===0)n.bufferSubData(c,0,u);else{h.sort((d,v)=>d.start-v.start);let f=0;for(let d=1;d<h.length;d++){const v=h[f],g=h[d];g.start<=v.start+v.count+1?v.count=Math.max(v.count,g.start+g.count-v.start):(++f,h[f]=g)}h.length=f+1;for(let d=0,v=h.length;d<v;d++){const g=h[d];n.bufferSubData(c,g.start*u.BYTES_PER_ELEMENT,u,g.start,g.count)}l.clearUpdateRanges()}l.onUploadCallback()}function r(a){return a.isInterleavedBufferAttribute&&(a=a.data),e.get(a)}function s(a){a.isInterleavedBufferAttribute&&(a=a.data);const l=e.get(a);l&&(n.deleteBuffer(l.buffer),e.delete(a))}function o(a,l){if(a.isInterleavedBufferAttribute&&(a=a.data),a.isGLBufferAttribute){const u=e.get(a);(!u||u.version<a.version)&&e.set(a,{buffer:a.buffer,type:a.type,bytesPerElement:a.elementSize,version:a.version});return}const c=e.get(a);if(c===void 0)e.set(a,t(a,l));else if(c.version<a.version){if(c.size!==a.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");i(c.buffer,a,l),c.version=a.version}}return{get:r,remove:s,update:o}}class as extends Et{constructor(e=1,t=1,i=1,r=1){super(),this.type="PlaneGeometry",this.parameters={width:e,height:t,widthSegments:i,heightSegments:r};const s=e/2,o=t/2,a=Math.floor(i),l=Math.floor(r),c=a+1,u=l+1,h=e/a,f=t/l,d=[],v=[],g=[],p=[];for(let m=0;m<u;m++){const x=m*f-o;for(let _=0;_<c;_++){const y=_*h-s;v.push(y,-x,0),g.push(0,0,1),p.push(_/a),p.push(1-m/l)}}for(let m=0;m<l;m++)for(let x=0;x<a;x++){const _=x+c*m,y=x+c*(m+1),C=x+1+c*(m+1),M=x+1+c*m;d.push(_,y,M),d.push(y,C,M)}this.setIndex(d),this.setAttribute("position",new nt(v,3)),this.setAttribute("normal",new nt(g,3)),this.setAttribute("uv",new nt(p,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new as(e.width,e.height,e.widthSegments,e.heightSegments)}}var hv=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,fv=`#ifdef USE_ALPHAHASH
	const float ALPHA_HASH_SCALE = 0.05;
	float hash2D( vec2 value ) {
		return fract( 1.0e4 * sin( 17.0 * value.x + 0.1 * value.y ) * ( 0.1 + abs( sin( 13.0 * value.y + value.x ) ) ) );
	}
	float hash3D( vec3 value ) {
		return hash2D( vec2( hash2D( value.xy ), value.z ) );
	}
	float getAlphaHashThreshold( vec3 position ) {
		float maxDeriv = max(
			length( dFdx( position.xyz ) ),
			length( dFdy( position.xyz ) )
		);
		float pixScale = 1.0 / ( ALPHA_HASH_SCALE * maxDeriv );
		vec2 pixScales = vec2(
			exp2( floor( log2( pixScale ) ) ),
			exp2( ceil( log2( pixScale ) ) )
		);
		vec2 alpha = vec2(
			hash3D( floor( pixScales.x * position.xyz ) ),
			hash3D( floor( pixScales.y * position.xyz ) )
		);
		float lerpFactor = fract( log2( pixScale ) );
		float x = ( 1.0 - lerpFactor ) * alpha.x + lerpFactor * alpha.y;
		float a = min( lerpFactor, 1.0 - lerpFactor );
		vec3 cases = vec3(
			x * x / ( 2.0 * a * ( 1.0 - a ) ),
			( x - 0.5 * a ) / ( 1.0 - a ),
			1.0 - ( ( 1.0 - x ) * ( 1.0 - x ) / ( 2.0 * a * ( 1.0 - a ) ) )
		);
		float threshold = ( x < ( 1.0 - a ) )
			? ( ( x < a ) ? cases.x : cases.y )
			: cases.z;
		return clamp( threshold , 1.0e-6, 1.0 );
	}
#endif`,dv=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,pv=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,mv=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,gv=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,vv=`#ifdef USE_AOMAP
	float ambientOcclusion = ( texture2D( aoMap, vAoMapUv ).r - 1.0 ) * aoMapIntensity + 1.0;
	reflectedLight.indirectDiffuse *= ambientOcclusion;
	#if defined( USE_CLEARCOAT ) 
		clearcoatSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_SHEEN ) 
		sheenSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD )
		float dotNV = saturate( dot( geometryNormal, geometryViewDir ) );
		reflectedLight.indirectSpecular *= computeSpecularOcclusion( dotNV, ambientOcclusion, material.roughness );
	#endif
#endif`,_v=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,xv=`#ifdef USE_BATCHING
	#if ! defined( GL_ANGLE_multi_draw )
	#define gl_DrawID _gl_DrawID
	uniform int _gl_DrawID;
	#endif
	uniform highp sampler2D batchingTexture;
	uniform highp usampler2D batchingIdTexture;
	mat4 getBatchingMatrix( const in float i ) {
		int size = textureSize( batchingTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( batchingTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( batchingTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( batchingTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( batchingTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
	float getIndirectIndex( const in int i ) {
		int size = textureSize( batchingIdTexture, 0 ).x;
		int x = i % size;
		int y = i / size;
		return float( texelFetch( batchingIdTexture, ivec2( x, y ), 0 ).r );
	}
#endif
#ifdef USE_BATCHING_COLOR
	uniform sampler2D batchingColorTexture;
	vec3 getBatchingColor( const in float i ) {
		int size = textureSize( batchingColorTexture, 0 ).x;
		int j = int( i );
		int x = j % size;
		int y = j / size;
		return texelFetch( batchingColorTexture, ivec2( x, y ), 0 ).rgb;
	}
#endif`,yv=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,Sv=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,Mv=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,bv=`float G_BlinnPhong_Implicit( ) {
	return 0.25;
}
float D_BlinnPhong( const in float shininess, const in float dotNH ) {
	return RECIPROCAL_PI * ( shininess * 0.5 + 1.0 ) * pow( dotNH, shininess );
}
vec3 BRDF_BlinnPhong( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in vec3 specularColor, const in float shininess ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( specularColor, 1.0, dotVH );
	float G = G_BlinnPhong_Implicit( );
	float D = D_BlinnPhong( shininess, dotNH );
	return F * ( G * D );
} // validated`,wv=`#ifdef USE_IRIDESCENCE
	const mat3 XYZ_TO_REC709 = mat3(
		 3.2404542, -0.9692660,  0.0556434,
		-1.5371385,  1.8760108, -0.2040259,
		-0.4985314,  0.0415560,  1.0572252
	);
	vec3 Fresnel0ToIor( vec3 fresnel0 ) {
		vec3 sqrtF0 = sqrt( fresnel0 );
		return ( vec3( 1.0 ) + sqrtF0 ) / ( vec3( 1.0 ) - sqrtF0 );
	}
	vec3 IorToFresnel0( vec3 transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - vec3( incidentIor ) ) / ( transmittedIor + vec3( incidentIor ) ) );
	}
	float IorToFresnel0( float transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - incidentIor ) / ( transmittedIor + incidentIor ));
	}
	vec3 evalSensitivity( float OPD, vec3 shift ) {
		float phase = 2.0 * PI * OPD * 1.0e-9;
		vec3 val = vec3( 5.4856e-13, 4.4201e-13, 5.2481e-13 );
		vec3 pos = vec3( 1.6810e+06, 1.7953e+06, 2.2084e+06 );
		vec3 var = vec3( 4.3278e+09, 9.3046e+09, 6.6121e+09 );
		vec3 xyz = val * sqrt( 2.0 * PI * var ) * cos( pos * phase + shift ) * exp( - pow2( phase ) * var );
		xyz.x += 9.7470e-14 * sqrt( 2.0 * PI * 4.5282e+09 ) * cos( 2.2399e+06 * phase + shift[ 0 ] ) * exp( - 4.5282e+09 * pow2( phase ) );
		xyz /= 1.0685e-7;
		vec3 rgb = XYZ_TO_REC709 * xyz;
		return rgb;
	}
	vec3 evalIridescence( float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0 ) {
		vec3 I;
		float iridescenceIOR = mix( outsideIOR, eta2, smoothstep( 0.0, 0.03, thinFilmThickness ) );
		float sinTheta2Sq = pow2( outsideIOR / iridescenceIOR ) * ( 1.0 - pow2( cosTheta1 ) );
		float cosTheta2Sq = 1.0 - sinTheta2Sq;
		if ( cosTheta2Sq < 0.0 ) {
			return vec3( 1.0 );
		}
		float cosTheta2 = sqrt( cosTheta2Sq );
		float R0 = IorToFresnel0( iridescenceIOR, outsideIOR );
		float R12 = F_Schlick( R0, 1.0, cosTheta1 );
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		if ( iridescenceIOR < outsideIOR ) phi12 = PI;
		float phi21 = PI - phi12;
		vec3 baseIOR = Fresnel0ToIor( clamp( baseF0, 0.0, 0.9999 ) );		vec3 R1 = IorToFresnel0( baseIOR, iridescenceIOR );
		vec3 R23 = F_Schlick( R1, 1.0, cosTheta2 );
		vec3 phi23 = vec3( 0.0 );
		if ( baseIOR[ 0 ] < iridescenceIOR ) phi23[ 0 ] = PI;
		if ( baseIOR[ 1 ] < iridescenceIOR ) phi23[ 1 ] = PI;
		if ( baseIOR[ 2 ] < iridescenceIOR ) phi23[ 2 ] = PI;
		float OPD = 2.0 * iridescenceIOR * thinFilmThickness * cosTheta2;
		vec3 phi = vec3( phi21 ) + phi23;
		vec3 R123 = clamp( R12 * R23, 1e-5, 0.9999 );
		vec3 r123 = sqrt( R123 );
		vec3 Rs = pow2( T121 ) * R23 / ( vec3( 1.0 ) - R123 );
		vec3 C0 = R12 + Rs;
		I = C0;
		vec3 Cm = Rs - T121;
		for ( int m = 1; m <= 2; ++ m ) {
			Cm *= r123;
			vec3 Sm = 2.0 * evalSensitivity( float( m ) * OPD, float( m ) * phi );
			I += Cm * Sm;
		}
		return max( I, vec3( 0.0 ) );
	}
#endif`,Ev=`#ifdef USE_BUMPMAP
	uniform sampler2D bumpMap;
	uniform float bumpScale;
	vec2 dHdxy_fwd() {
		vec2 dSTdx = dFdx( vBumpMapUv );
		vec2 dSTdy = dFdy( vBumpMapUv );
		float Hll = bumpScale * texture2D( bumpMap, vBumpMapUv ).x;
		float dBx = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdx ).x - Hll;
		float dBy = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdy ).x - Hll;
		return vec2( dBx, dBy );
	}
	vec3 perturbNormalArb( vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDirection ) {
		vec3 vSigmaX = normalize( dFdx( surf_pos.xyz ) );
		vec3 vSigmaY = normalize( dFdy( surf_pos.xyz ) );
		vec3 vN = surf_norm;
		vec3 R1 = cross( vSigmaY, vN );
		vec3 R2 = cross( vN, vSigmaX );
		float fDet = dot( vSigmaX, R1 ) * faceDirection;
		vec3 vGrad = sign( fDet ) * ( dHdxy.x * R1 + dHdxy.y * R2 );
		return normalize( abs( fDet ) * surf_norm - vGrad );
	}
#endif`,Tv=`#if NUM_CLIPPING_PLANES > 0
	vec4 plane;
	#ifdef ALPHA_TO_COVERAGE
		float distanceToPlane, distanceGradient;
		float clipOpacity = 1.0;
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
			distanceGradient = fwidth( distanceToPlane ) / 2.0;
			clipOpacity *= smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			if ( clipOpacity == 0.0 ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			float unionClipOpacity = 1.0;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
				distanceGradient = fwidth( distanceToPlane ) / 2.0;
				unionClipOpacity *= 1.0 - smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			}
			#pragma unroll_loop_end
			clipOpacity *= 1.0 - unionClipOpacity;
		#endif
		diffuseColor.a *= clipOpacity;
		if ( diffuseColor.a == 0.0 ) discard;
	#else
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			if ( dot( vClipPosition, plane.xyz ) > plane.w ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			bool clipped = true;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				clipped = ( dot( vClipPosition, plane.xyz ) > plane.w ) && clipped;
			}
			#pragma unroll_loop_end
			if ( clipped ) discard;
		#endif
	#endif
#endif`,Av=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,Cv=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,Rv=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,Pv=`#if defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#elif defined( USE_COLOR )
	diffuseColor.rgb *= vColor;
#endif`,Lv=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR )
	varying vec3 vColor;
#endif`,Dv=`#if defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec3 vColor;
#endif`,Iv=`#if defined( USE_COLOR_ALPHA )
	vColor = vec4( 1.0 );
#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	vColor = vec3( 1.0 );
#endif
#ifdef USE_COLOR
	vColor *= color;
#endif
#ifdef USE_INSTANCING_COLOR
	vColor.xyz *= instanceColor.xyz;
#endif
#ifdef USE_BATCHING_COLOR
	vec3 batchingColor = getBatchingColor( getIndirectIndex( gl_DrawID ) );
	vColor.xyz *= batchingColor.xyz;
#endif`,Uv=`#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6
#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
#define whiteComplement( a ) ( 1.0 - saturate( a ) )
float pow2( const in float x ) { return x*x; }
vec3 pow2( const in vec3 x ) { return x*x; }
float pow3( const in float x ) { return x*x*x; }
float pow4( const in float x ) { float x2 = x*x; return x2*x2; }
float max3( const in vec3 v ) { return max( max( v.x, v.y ), v.z ); }
float average( const in vec3 v ) { return dot( v, vec3( 0.3333333 ) ); }
highp float rand( const in vec2 uv ) {
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract( sin( sn ) * c );
}
#ifdef HIGH_PRECISION
	float precisionSafeLength( vec3 v ) { return length( v ); }
#else
	float precisionSafeLength( vec3 v ) {
		float maxComponent = max3( abs( v ) );
		return length( v / maxComponent ) * maxComponent;
	}
#endif
struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};
struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};
#ifdef USE_ALPHAHASH
	varying vec3 vPosition;
#endif
vec3 transformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );
}
vec3 inverseTransformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( vec4( dir, 0.0 ) * matrix ).xyz );
}
mat3 transposeMat3( const in mat3 m ) {
	mat3 tmp;
	tmp[ 0 ] = vec3( m[ 0 ].x, m[ 1 ].x, m[ 2 ].x );
	tmp[ 1 ] = vec3( m[ 0 ].y, m[ 1 ].y, m[ 2 ].y );
	tmp[ 2 ] = vec3( m[ 0 ].z, m[ 1 ].z, m[ 2 ].z );
	return tmp;
}
bool isPerspectiveMatrix( mat4 m ) {
	return m[ 2 ][ 3 ] == - 1.0;
}
vec2 equirectUv( in vec3 dir ) {
	float u = atan( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;
	float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;
	return vec2( u, v );
}
vec3 BRDF_Lambert( const in vec3 diffuseColor ) {
	return RECIPROCAL_PI * diffuseColor;
}
vec3 F_Schlick( const in vec3 f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
}
float F_Schlick( const in float f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
} // validated`,Nv=`#ifdef ENVMAP_TYPE_CUBE_UV
	#define cubeUV_minMipLevel 4.0
	#define cubeUV_minTileSize 16.0
	float getFace( vec3 direction ) {
		vec3 absDirection = abs( direction );
		float face = - 1.0;
		if ( absDirection.x > absDirection.z ) {
			if ( absDirection.x > absDirection.y )
				face = direction.x > 0.0 ? 0.0 : 3.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		} else {
			if ( absDirection.z > absDirection.y )
				face = direction.z > 0.0 ? 2.0 : 5.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		}
		return face;
	}
	vec2 getUV( vec3 direction, float face ) {
		vec2 uv;
		if ( face == 0.0 ) {
			uv = vec2( direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 1.0 ) {
			uv = vec2( - direction.x, - direction.z ) / abs( direction.y );
		} else if ( face == 2.0 ) {
			uv = vec2( - direction.x, direction.y ) / abs( direction.z );
		} else if ( face == 3.0 ) {
			uv = vec2( - direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 4.0 ) {
			uv = vec2( - direction.x, direction.z ) / abs( direction.y );
		} else {
			uv = vec2( direction.x, direction.y ) / abs( direction.z );
		}
		return 0.5 * ( uv + 1.0 );
	}
	vec3 bilinearCubeUV( sampler2D envMap, vec3 direction, float mipInt ) {
		float face = getFace( direction );
		float filterInt = max( cubeUV_minMipLevel - mipInt, 0.0 );
		mipInt = max( mipInt, cubeUV_minMipLevel );
		float faceSize = exp2( mipInt );
		highp vec2 uv = getUV( direction, face ) * ( faceSize - 2.0 ) + 1.0;
		if ( face > 2.0 ) {
			uv.y += faceSize;
			face -= 3.0;
		}
		uv.x += face * faceSize;
		uv.x += filterInt * 3.0 * cubeUV_minTileSize;
		uv.y += 4.0 * ( exp2( CUBEUV_MAX_MIP ) - faceSize );
		uv.x *= CUBEUV_TEXEL_WIDTH;
		uv.y *= CUBEUV_TEXEL_HEIGHT;
		#ifdef texture2DGradEXT
			return texture2DGradEXT( envMap, uv, vec2( 0.0 ), vec2( 0.0 ) ).rgb;
		#else
			return texture2D( envMap, uv ).rgb;
		#endif
	}
	#define cubeUV_r0 1.0
	#define cubeUV_m0 - 2.0
	#define cubeUV_r1 0.8
	#define cubeUV_m1 - 1.0
	#define cubeUV_r4 0.4
	#define cubeUV_m4 2.0
	#define cubeUV_r5 0.305
	#define cubeUV_m5 3.0
	#define cubeUV_r6 0.21
	#define cubeUV_m6 4.0
	float roughnessToMip( float roughness ) {
		float mip = 0.0;
		if ( roughness >= cubeUV_r1 ) {
			mip = ( cubeUV_r0 - roughness ) * ( cubeUV_m1 - cubeUV_m0 ) / ( cubeUV_r0 - cubeUV_r1 ) + cubeUV_m0;
		} else if ( roughness >= cubeUV_r4 ) {
			mip = ( cubeUV_r1 - roughness ) * ( cubeUV_m4 - cubeUV_m1 ) / ( cubeUV_r1 - cubeUV_r4 ) + cubeUV_m1;
		} else if ( roughness >= cubeUV_r5 ) {
			mip = ( cubeUV_r4 - roughness ) * ( cubeUV_m5 - cubeUV_m4 ) / ( cubeUV_r4 - cubeUV_r5 ) + cubeUV_m4;
		} else if ( roughness >= cubeUV_r6 ) {
			mip = ( cubeUV_r5 - roughness ) * ( cubeUV_m6 - cubeUV_m5 ) / ( cubeUV_r5 - cubeUV_r6 ) + cubeUV_m5;
		} else {
			mip = - 2.0 * log2( 1.16 * roughness );		}
		return mip;
	}
	vec4 textureCubeUV( sampler2D envMap, vec3 sampleDir, float roughness ) {
		float mip = clamp( roughnessToMip( roughness ), cubeUV_m0, CUBEUV_MAX_MIP );
		float mipF = fract( mip );
		float mipInt = floor( mip );
		vec3 color0 = bilinearCubeUV( envMap, sampleDir, mipInt );
		if ( mipF == 0.0 ) {
			return vec4( color0, 1.0 );
		} else {
			vec3 color1 = bilinearCubeUV( envMap, sampleDir, mipInt + 1.0 );
			return vec4( mix( color0, color1, mipF ), 1.0 );
		}
	}
#endif`,Fv=`vec3 transformedNormal = objectNormal;
#ifdef USE_TANGENT
	vec3 transformedTangent = objectTangent;
#endif
#ifdef USE_BATCHING
	mat3 bm = mat3( batchingMatrix );
	transformedNormal /= vec3( dot( bm[ 0 ], bm[ 0 ] ), dot( bm[ 1 ], bm[ 1 ] ), dot( bm[ 2 ], bm[ 2 ] ) );
	transformedNormal = bm * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = bm * transformedTangent;
	#endif
#endif
#ifdef USE_INSTANCING
	mat3 im = mat3( instanceMatrix );
	transformedNormal /= vec3( dot( im[ 0 ], im[ 0 ] ), dot( im[ 1 ], im[ 1 ] ), dot( im[ 2 ], im[ 2 ] ) );
	transformedNormal = im * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = im * transformedTangent;
	#endif
#endif
transformedNormal = normalMatrix * transformedNormal;
#ifdef FLIP_SIDED
	transformedNormal = - transformedNormal;
#endif
#ifdef USE_TANGENT
	transformedTangent = ( modelViewMatrix * vec4( transformedTangent, 0.0 ) ).xyz;
	#ifdef FLIP_SIDED
		transformedTangent = - transformedTangent;
	#endif
#endif`,Ov=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,kv=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,Bv=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,zv=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,Hv="gl_FragColor = linearToOutputTexel( gl_FragColor );",Gv=`
const mat3 LINEAR_SRGB_TO_LINEAR_DISPLAY_P3 = mat3(
	vec3( 0.8224621, 0.177538, 0.0 ),
	vec3( 0.0331941, 0.9668058, 0.0 ),
	vec3( 0.0170827, 0.0723974, 0.9105199 )
);
const mat3 LINEAR_DISPLAY_P3_TO_LINEAR_SRGB = mat3(
	vec3( 1.2249401, - 0.2249404, 0.0 ),
	vec3( - 0.0420569, 1.0420571, 0.0 ),
	vec3( - 0.0196376, - 0.0786361, 1.0982735 )
);
vec4 LinearSRGBToLinearDisplayP3( in vec4 value ) {
	return vec4( value.rgb * LINEAR_SRGB_TO_LINEAR_DISPLAY_P3, value.a );
}
vec4 LinearDisplayP3ToLinearSRGB( in vec4 value ) {
	return vec4( value.rgb * LINEAR_DISPLAY_P3_TO_LINEAR_SRGB, value.a );
}
vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,Vv=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vec3 cameraToFrag;
		if ( isOrthographic ) {
			cameraToFrag = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToFrag = normalize( vWorldPosition - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vec3 reflectVec = reflect( cameraToFrag, worldNormal );
		#else
			vec3 reflectVec = refract( cameraToFrag, worldNormal, refractionRatio );
		#endif
	#else
		vec3 reflectVec = vReflect;
	#endif
	#ifdef ENVMAP_TYPE_CUBE
		vec4 envColor = textureCube( envMap, envMapRotation * vec3( flipEnvMap * reflectVec.x, reflectVec.yz ) );
	#else
		vec4 envColor = vec4( 0.0 );
	#endif
	#ifdef ENVMAP_BLENDING_MULTIPLY
		outgoingLight = mix( outgoingLight, outgoingLight * envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_MIX )
		outgoingLight = mix( outgoingLight, envColor.xyz, specularStrength * reflectivity );
	#elif defined( ENVMAP_BLENDING_ADD )
		outgoingLight += envColor.xyz * specularStrength * reflectivity;
	#endif
#endif`,Wv=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform float flipEnvMap;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
	
#endif`,Xv=`#ifdef USE_ENVMAP
	uniform float reflectivity;
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		varying vec3 vWorldPosition;
		uniform float refractionRatio;
	#else
		varying vec3 vReflect;
	#endif
#endif`,qv=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,$v=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vWorldPosition = worldPosition.xyz;
	#else
		vec3 cameraToVertex;
		if ( isOrthographic ) {
			cameraToVertex = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToVertex = normalize( worldPosition.xyz - cameraPosition );
		}
		vec3 worldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vReflect = reflect( cameraToVertex, worldNormal );
		#else
			vReflect = refract( cameraToVertex, worldNormal, refractionRatio );
		#endif
	#endif
#endif`,Yv=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,Kv=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,jv=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,Zv=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,Jv=`#ifdef USE_GRADIENTMAP
	uniform sampler2D gradientMap;
#endif
vec3 getGradientIrradiance( vec3 normal, vec3 lightDirection ) {
	float dotNL = dot( normal, lightDirection );
	vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );
	#ifdef USE_GRADIENTMAP
		return vec3( texture2D( gradientMap, coord ).r );
	#else
		vec2 fw = fwidth( coord ) * 0.5;
		return mix( vec3( 0.7 ), vec3( 1.0 ), smoothstep( 0.7 - fw.x, 0.7 + fw.x, coord.x ) );
	#endif
}`,Qv=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,e_=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,t_=`varying vec3 vViewPosition;
struct LambertMaterial {
	vec3 diffuseColor;
	float specularStrength;
};
void RE_Direct_Lambert( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Lambert( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Lambert
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,n_=`uniform bool receiveShadow;
uniform vec3 ambientLightColor;
#if defined( USE_LIGHT_PROBES )
	uniform vec3 lightProbe[ 9 ];
#endif
vec3 shGetIrradianceAt( in vec3 normal, in vec3 shCoefficients[ 9 ] ) {
	float x = normal.x, y = normal.y, z = normal.z;
	vec3 result = shCoefficients[ 0 ] * 0.886227;
	result += shCoefficients[ 1 ] * 2.0 * 0.511664 * y;
	result += shCoefficients[ 2 ] * 2.0 * 0.511664 * z;
	result += shCoefficients[ 3 ] * 2.0 * 0.511664 * x;
	result += shCoefficients[ 4 ] * 2.0 * 0.429043 * x * y;
	result += shCoefficients[ 5 ] * 2.0 * 0.429043 * y * z;
	result += shCoefficients[ 6 ] * ( 0.743125 * z * z - 0.247708 );
	result += shCoefficients[ 7 ] * 2.0 * 0.429043 * x * z;
	result += shCoefficients[ 8 ] * 0.429043 * ( x * x - y * y );
	return result;
}
vec3 getLightProbeIrradiance( const in vec3 lightProbe[ 9 ], const in vec3 normal ) {
	vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
	vec3 irradiance = shGetIrradianceAt( worldNormal, lightProbe );
	return irradiance;
}
vec3 getAmbientLightIrradiance( const in vec3 ambientLightColor ) {
	vec3 irradiance = ambientLightColor;
	return irradiance;
}
float getDistanceAttenuation( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {
	float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), 0.01 );
	if ( cutoffDistance > 0.0 ) {
		distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );
	}
	return distanceFalloff;
}
float getSpotAttenuation( const in float coneCosine, const in float penumbraCosine, const in float angleCosine ) {
	return smoothstep( coneCosine, penumbraCosine, angleCosine );
}
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;
	};
	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];
	void getDirectionalLightInfo( const in DirectionalLight directionalLight, out IncidentLight light ) {
		light.color = directionalLight.color;
		light.direction = directionalLight.direction;
		light.visible = true;
	}
#endif
#if NUM_POINT_LIGHTS > 0
	struct PointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;
	};
	uniform PointLight pointLights[ NUM_POINT_LIGHTS ];
	void getPointLightInfo( const in PointLight pointLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = pointLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float lightDistance = length( lVector );
		light.color = pointLight.color;
		light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
		light.visible = ( light.color != vec3( 0.0 ) );
	}
#endif
#if NUM_SPOT_LIGHTS > 0
	struct SpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;
	};
	uniform SpotLight spotLights[ NUM_SPOT_LIGHTS ];
	void getSpotLightInfo( const in SpotLight spotLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = spotLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float angleCos = dot( light.direction, spotLight.direction );
		float spotAttenuation = getSpotAttenuation( spotLight.coneCos, spotLight.penumbraCos, angleCos );
		if ( spotAttenuation > 0.0 ) {
			float lightDistance = length( lVector );
			light.color = spotLight.color * spotAttenuation;
			light.color *= getDistanceAttenuation( lightDistance, spotLight.distance, spotLight.decay );
			light.visible = ( light.color != vec3( 0.0 ) );
		} else {
			light.color = vec3( 0.0 );
			light.visible = false;
		}
	}
#endif
#if NUM_RECT_AREA_LIGHTS > 0
	struct RectAreaLight {
		vec3 color;
		vec3 position;
		vec3 halfWidth;
		vec3 halfHeight;
	};
	uniform sampler2D ltc_1;	uniform sampler2D ltc_2;
	uniform RectAreaLight rectAreaLights[ NUM_RECT_AREA_LIGHTS ];
#endif
#if NUM_HEMI_LIGHTS > 0
	struct HemisphereLight {
		vec3 direction;
		vec3 skyColor;
		vec3 groundColor;
	};
	uniform HemisphereLight hemisphereLights[ NUM_HEMI_LIGHTS ];
	vec3 getHemisphereLightIrradiance( const in HemisphereLight hemiLight, const in vec3 normal ) {
		float dotNL = dot( normal, hemiLight.direction );
		float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
		vec3 irradiance = mix( hemiLight.groundColor, hemiLight.skyColor, hemiDiffuseWeight );
		return irradiance;
	}
#endif`,i_=`#ifdef USE_ENVMAP
	vec3 getIBLIrradiance( const in vec3 normal ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 worldNormal = inverseTransformDirection( normal, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * worldNormal, 1.0 );
			return PI * envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	vec3 getIBLRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 reflectVec = reflect( - viewDir, normal );
			reflectVec = normalize( mix( reflectVec, normal, roughness * roughness) );
			reflectVec = inverseTransformDirection( reflectVec, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * reflectVec, roughness );
			return envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	#ifdef USE_ANISOTROPY
		vec3 getIBLAnisotropyRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness, const in vec3 bitangent, const in float anisotropy ) {
			#ifdef ENVMAP_TYPE_CUBE_UV
				vec3 bentNormal = cross( bitangent, viewDir );
				bentNormal = normalize( cross( bentNormal, bitangent ) );
				bentNormal = normalize( mix( bentNormal, normal, pow2( pow2( 1.0 - anisotropy * ( 1.0 - roughness ) ) ) ) );
				return getIBLRadiance( viewDir, bentNormal, roughness );
			#else
				return vec3( 0.0 );
			#endif
		}
	#endif
#endif`,r_=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,s_=`varying vec3 vViewPosition;
struct ToonMaterial {
	vec3 diffuseColor;
};
void RE_Direct_Toon( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	vec3 irradiance = getGradientIrradiance( geometryNormal, directLight.direction ) * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Toon( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Toon
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,o_=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,a_=`varying vec3 vViewPosition;
struct BlinnPhongMaterial {
	vec3 diffuseColor;
	vec3 specularColor;
	float specularShininess;
	float specularStrength;
};
void RE_Direct_BlinnPhong( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
	reflectedLight.directSpecular += irradiance * BRDF_BlinnPhong( directLight.direction, geometryViewDir, geometryNormal, material.specularColor, material.specularShininess ) * material.specularStrength;
}
void RE_IndirectDiffuse_BlinnPhong( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_BlinnPhong
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,l_=`PhysicalMaterial material;
material.diffuseColor = diffuseColor.rgb * ( 1.0 - metalnessFactor );
vec3 dxy = max( abs( dFdx( nonPerturbedNormal ) ), abs( dFdy( nonPerturbedNormal ) ) );
float geometryRoughness = max( max( dxy.x, dxy.y ), dxy.z );
material.roughness = max( roughnessFactor, 0.0525 );material.roughness += geometryRoughness;
material.roughness = min( material.roughness, 1.0 );
#ifdef IOR
	material.ior = ior;
	#ifdef USE_SPECULAR
		float specularIntensityFactor = specularIntensity;
		vec3 specularColorFactor = specularColor;
		#ifdef USE_SPECULAR_COLORMAP
			specularColorFactor *= texture2D( specularColorMap, vSpecularColorMapUv ).rgb;
		#endif
		#ifdef USE_SPECULAR_INTENSITYMAP
			specularIntensityFactor *= texture2D( specularIntensityMap, vSpecularIntensityMapUv ).a;
		#endif
		material.specularF90 = mix( specularIntensityFactor, 1.0, metalnessFactor );
	#else
		float specularIntensityFactor = 1.0;
		vec3 specularColorFactor = vec3( 1.0 );
		material.specularF90 = 1.0;
	#endif
	material.specularColor = mix( min( pow2( ( material.ior - 1.0 ) / ( material.ior + 1.0 ) ) * specularColorFactor, vec3( 1.0 ) ) * specularIntensityFactor, diffuseColor.rgb, metalnessFactor );
#else
	material.specularColor = mix( vec3( 0.04 ), diffuseColor.rgb, metalnessFactor );
	material.specularF90 = 1.0;
#endif
#ifdef USE_CLEARCOAT
	material.clearcoat = clearcoat;
	material.clearcoatRoughness = clearcoatRoughness;
	material.clearcoatF0 = vec3( 0.04 );
	material.clearcoatF90 = 1.0;
	#ifdef USE_CLEARCOATMAP
		material.clearcoat *= texture2D( clearcoatMap, vClearcoatMapUv ).x;
	#endif
	#ifdef USE_CLEARCOAT_ROUGHNESSMAP
		material.clearcoatRoughness *= texture2D( clearcoatRoughnessMap, vClearcoatRoughnessMapUv ).y;
	#endif
	material.clearcoat = saturate( material.clearcoat );	material.clearcoatRoughness = max( material.clearcoatRoughness, 0.0525 );
	material.clearcoatRoughness += geometryRoughness;
	material.clearcoatRoughness = min( material.clearcoatRoughness, 1.0 );
#endif
#ifdef USE_DISPERSION
	material.dispersion = dispersion;
#endif
#ifdef USE_IRIDESCENCE
	material.iridescence = iridescence;
	material.iridescenceIOR = iridescenceIOR;
	#ifdef USE_IRIDESCENCEMAP
		material.iridescence *= texture2D( iridescenceMap, vIridescenceMapUv ).r;
	#endif
	#ifdef USE_IRIDESCENCE_THICKNESSMAP
		material.iridescenceThickness = (iridescenceThicknessMaximum - iridescenceThicknessMinimum) * texture2D( iridescenceThicknessMap, vIridescenceThicknessMapUv ).g + iridescenceThicknessMinimum;
	#else
		material.iridescenceThickness = iridescenceThicknessMaximum;
	#endif
#endif
#ifdef USE_SHEEN
	material.sheenColor = sheenColor;
	#ifdef USE_SHEEN_COLORMAP
		material.sheenColor *= texture2D( sheenColorMap, vSheenColorMapUv ).rgb;
	#endif
	material.sheenRoughness = clamp( sheenRoughness, 0.07, 1.0 );
	#ifdef USE_SHEEN_ROUGHNESSMAP
		material.sheenRoughness *= texture2D( sheenRoughnessMap, vSheenRoughnessMapUv ).a;
	#endif
#endif
#ifdef USE_ANISOTROPY
	#ifdef USE_ANISOTROPYMAP
		mat2 anisotropyMat = mat2( anisotropyVector.x, anisotropyVector.y, - anisotropyVector.y, anisotropyVector.x );
		vec3 anisotropyPolar = texture2D( anisotropyMap, vAnisotropyMapUv ).rgb;
		vec2 anisotropyV = anisotropyMat * normalize( 2.0 * anisotropyPolar.rg - vec2( 1.0 ) ) * anisotropyPolar.b;
	#else
		vec2 anisotropyV = anisotropyVector;
	#endif
	material.anisotropy = length( anisotropyV );
	if( material.anisotropy == 0.0 ) {
		anisotropyV = vec2( 1.0, 0.0 );
	} else {
		anisotropyV /= material.anisotropy;
		material.anisotropy = saturate( material.anisotropy );
	}
	material.alphaT = mix( pow2( material.roughness ), 1.0, pow2( material.anisotropy ) );
	material.anisotropyT = tbn[ 0 ] * anisotropyV.x + tbn[ 1 ] * anisotropyV.y;
	material.anisotropyB = tbn[ 1 ] * anisotropyV.x - tbn[ 0 ] * anisotropyV.y;
#endif`,c_=`struct PhysicalMaterial {
	vec3 diffuseColor;
	float roughness;
	vec3 specularColor;
	float specularF90;
	float dispersion;
	#ifdef USE_CLEARCOAT
		float clearcoat;
		float clearcoatRoughness;
		vec3 clearcoatF0;
		float clearcoatF90;
	#endif
	#ifdef USE_IRIDESCENCE
		float iridescence;
		float iridescenceIOR;
		float iridescenceThickness;
		vec3 iridescenceFresnel;
		vec3 iridescenceF0;
	#endif
	#ifdef USE_SHEEN
		vec3 sheenColor;
		float sheenRoughness;
	#endif
	#ifdef IOR
		float ior;
	#endif
	#ifdef USE_TRANSMISSION
		float transmission;
		float transmissionAlpha;
		float thickness;
		float attenuationDistance;
		vec3 attenuationColor;
	#endif
	#ifdef USE_ANISOTROPY
		float anisotropy;
		float alphaT;
		vec3 anisotropyT;
		vec3 anisotropyB;
	#endif
};
vec3 clearcoatSpecularDirect = vec3( 0.0 );
vec3 clearcoatSpecularIndirect = vec3( 0.0 );
vec3 sheenSpecularDirect = vec3( 0.0 );
vec3 sheenSpecularIndirect = vec3(0.0 );
vec3 Schlick_to_F0( const in vec3 f, const in float f90, const in float dotVH ) {
    float x = clamp( 1.0 - dotVH, 0.0, 1.0 );
    float x2 = x * x;
    float x5 = clamp( x * x2 * x2, 0.0, 0.9999 );
    return ( f - vec3( f90 ) * x5 ) / ( 1.0 - x5 );
}
float V_GGX_SmithCorrelated( const in float alpha, const in float dotNL, const in float dotNV ) {
	float a2 = pow2( alpha );
	float gv = dotNL * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );
	float gl = dotNV * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );
	return 0.5 / max( gv + gl, EPSILON );
}
float D_GGX( const in float alpha, const in float dotNH ) {
	float a2 = pow2( alpha );
	float denom = pow2( dotNH ) * ( a2 - 1.0 ) + 1.0;
	return RECIPROCAL_PI * a2 / pow2( denom );
}
#ifdef USE_ANISOTROPY
	float V_GGX_SmithCorrelated_Anisotropic( const in float alphaT, const in float alphaB, const in float dotTV, const in float dotBV, const in float dotTL, const in float dotBL, const in float dotNV, const in float dotNL ) {
		float gv = dotNL * length( vec3( alphaT * dotTV, alphaB * dotBV, dotNV ) );
		float gl = dotNV * length( vec3( alphaT * dotTL, alphaB * dotBL, dotNL ) );
		float v = 0.5 / ( gv + gl );
		return saturate(v);
	}
	float D_GGX_Anisotropic( const in float alphaT, const in float alphaB, const in float dotNH, const in float dotTH, const in float dotBH ) {
		float a2 = alphaT * alphaB;
		highp vec3 v = vec3( alphaB * dotTH, alphaT * dotBH, a2 * dotNH );
		highp float v2 = dot( v, v );
		float w2 = a2 / v2;
		return RECIPROCAL_PI * a2 * pow2 ( w2 );
	}
#endif
#ifdef USE_CLEARCOAT
	vec3 BRDF_GGX_Clearcoat( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material) {
		vec3 f0 = material.clearcoatF0;
		float f90 = material.clearcoatF90;
		float roughness = material.clearcoatRoughness;
		float alpha = pow2( roughness );
		vec3 halfDir = normalize( lightDir + viewDir );
		float dotNL = saturate( dot( normal, lightDir ) );
		float dotNV = saturate( dot( normal, viewDir ) );
		float dotNH = saturate( dot( normal, halfDir ) );
		float dotVH = saturate( dot( viewDir, halfDir ) );
		vec3 F = F_Schlick( f0, f90, dotVH );
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
		return F * ( V * D );
	}
#endif
vec3 BRDF_GGX( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material ) {
	vec3 f0 = material.specularColor;
	float f90 = material.specularF90;
	float roughness = material.roughness;
	float alpha = pow2( roughness );
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( f0, f90, dotVH );
	#ifdef USE_IRIDESCENCE
		F = mix( F, material.iridescenceFresnel, material.iridescence );
	#endif
	#ifdef USE_ANISOTROPY
		float dotTL = dot( material.anisotropyT, lightDir );
		float dotTV = dot( material.anisotropyT, viewDir );
		float dotTH = dot( material.anisotropyT, halfDir );
		float dotBL = dot( material.anisotropyB, lightDir );
		float dotBV = dot( material.anisotropyB, viewDir );
		float dotBH = dot( material.anisotropyB, halfDir );
		float V = V_GGX_SmithCorrelated_Anisotropic( material.alphaT, alpha, dotTV, dotBV, dotTL, dotBL, dotNV, dotNL );
		float D = D_GGX_Anisotropic( material.alphaT, alpha, dotNH, dotTH, dotBH );
	#else
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
	#endif
	return F * ( V * D );
}
vec2 LTC_Uv( const in vec3 N, const in vec3 V, const in float roughness ) {
	const float LUT_SIZE = 64.0;
	const float LUT_SCALE = ( LUT_SIZE - 1.0 ) / LUT_SIZE;
	const float LUT_BIAS = 0.5 / LUT_SIZE;
	float dotNV = saturate( dot( N, V ) );
	vec2 uv = vec2( roughness, sqrt( 1.0 - dotNV ) );
	uv = uv * LUT_SCALE + LUT_BIAS;
	return uv;
}
float LTC_ClippedSphereFormFactor( const in vec3 f ) {
	float l = length( f );
	return max( ( l * l + f.z ) / ( l + 1.0 ), 0.0 );
}
vec3 LTC_EdgeVectorFormFactor( const in vec3 v1, const in vec3 v2 ) {
	float x = dot( v1, v2 );
	float y = abs( x );
	float a = 0.8543985 + ( 0.4965155 + 0.0145206 * y ) * y;
	float b = 3.4175940 + ( 4.1616724 + y ) * y;
	float v = a / b;
	float theta_sintheta = ( x > 0.0 ) ? v : 0.5 * inversesqrt( max( 1.0 - x * x, 1e-7 ) ) - v;
	return cross( v1, v2 ) * theta_sintheta;
}
vec3 LTC_Evaluate( const in vec3 N, const in vec3 V, const in vec3 P, const in mat3 mInv, const in vec3 rectCoords[ 4 ] ) {
	vec3 v1 = rectCoords[ 1 ] - rectCoords[ 0 ];
	vec3 v2 = rectCoords[ 3 ] - rectCoords[ 0 ];
	vec3 lightNormal = cross( v1, v2 );
	if( dot( lightNormal, P - rectCoords[ 0 ] ) < 0.0 ) return vec3( 0.0 );
	vec3 T1, T2;
	T1 = normalize( V - N * dot( V, N ) );
	T2 = - cross( N, T1 );
	mat3 mat = mInv * transposeMat3( mat3( T1, T2, N ) );
	vec3 coords[ 4 ];
	coords[ 0 ] = mat * ( rectCoords[ 0 ] - P );
	coords[ 1 ] = mat * ( rectCoords[ 1 ] - P );
	coords[ 2 ] = mat * ( rectCoords[ 2 ] - P );
	coords[ 3 ] = mat * ( rectCoords[ 3 ] - P );
	coords[ 0 ] = normalize( coords[ 0 ] );
	coords[ 1 ] = normalize( coords[ 1 ] );
	coords[ 2 ] = normalize( coords[ 2 ] );
	coords[ 3 ] = normalize( coords[ 3 ] );
	vec3 vectorFormFactor = vec3( 0.0 );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 0 ], coords[ 1 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 1 ], coords[ 2 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 2 ], coords[ 3 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 3 ], coords[ 0 ] );
	float result = LTC_ClippedSphereFormFactor( vectorFormFactor );
	return vec3( result );
}
#if defined( USE_SHEEN )
float D_Charlie( float roughness, float dotNH ) {
	float alpha = pow2( roughness );
	float invAlpha = 1.0 / alpha;
	float cos2h = dotNH * dotNH;
	float sin2h = max( 1.0 - cos2h, 0.0078125 );
	return ( 2.0 + invAlpha ) * pow( sin2h, invAlpha * 0.5 ) / ( 2.0 * PI );
}
float V_Neubelt( float dotNV, float dotNL ) {
	return saturate( 1.0 / ( 4.0 * ( dotNL + dotNV - dotNL * dotNV ) ) );
}
vec3 BRDF_Sheen( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, vec3 sheenColor, const in float sheenRoughness ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float D = D_Charlie( sheenRoughness, dotNH );
	float V = V_Neubelt( dotNV, dotNL );
	return sheenColor * ( D * V );
}
#endif
float IBLSheenBRDF( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	float r2 = roughness * roughness;
	float a = roughness < 0.25 ? -339.2 * r2 + 161.4 * roughness - 25.9 : -8.48 * r2 + 14.3 * roughness - 9.95;
	float b = roughness < 0.25 ? 44.0 * r2 - 23.7 * roughness + 3.26 : 1.97 * r2 - 3.27 * roughness + 0.72;
	float DG = exp( a * dotNV + b ) + ( roughness < 0.25 ? 0.0 : 0.1 * ( roughness - 0.25 ) );
	return saturate( DG * RECIPROCAL_PI );
}
vec2 DFGApprox( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	const vec4 c0 = vec4( - 1, - 0.0275, - 0.572, 0.022 );
	const vec4 c1 = vec4( 1, 0.0425, 1.04, - 0.04 );
	vec4 r = roughness * c0 + c1;
	float a004 = min( r.x * r.x, exp2( - 9.28 * dotNV ) ) * r.x + r.y;
	vec2 fab = vec2( - 1.04, 1.04 ) * a004 + r.zw;
	return fab;
}
vec3 EnvironmentBRDF( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness ) {
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	return specularColor * fab.x + specularF90 * fab.y;
}
#ifdef USE_IRIDESCENCE
void computeMultiscatteringIridescence( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float iridescence, const in vec3 iridescenceF0, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#else
void computeMultiscattering( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness, inout vec3 singleScatter, inout vec3 multiScatter ) {
#endif
	vec2 fab = DFGApprox( normal, viewDir, roughness );
	#ifdef USE_IRIDESCENCE
		vec3 Fr = mix( specularColor, iridescenceF0, iridescence );
	#else
		vec3 Fr = specularColor;
	#endif
	vec3 FssEss = Fr * fab.x + specularF90 * fab.y;
	float Ess = fab.x + fab.y;
	float Ems = 1.0 - Ess;
	vec3 Favg = Fr + ( 1.0 - Fr ) * 0.047619;	vec3 Fms = FssEss * Favg / ( 1.0 - Ems * Favg );
	singleScatter += FssEss;
	multiScatter += Fms * Ems;
}
#if NUM_RECT_AREA_LIGHTS > 0
	void RE_Direct_RectArea_Physical( const in RectAreaLight rectAreaLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
		vec3 normal = geometryNormal;
		vec3 viewDir = geometryViewDir;
		vec3 position = geometryPosition;
		vec3 lightPos = rectAreaLight.position;
		vec3 halfWidth = rectAreaLight.halfWidth;
		vec3 halfHeight = rectAreaLight.halfHeight;
		vec3 lightColor = rectAreaLight.color;
		float roughness = material.roughness;
		vec3 rectCoords[ 4 ];
		rectCoords[ 0 ] = lightPos + halfWidth - halfHeight;		rectCoords[ 1 ] = lightPos - halfWidth - halfHeight;
		rectCoords[ 2 ] = lightPos - halfWidth + halfHeight;
		rectCoords[ 3 ] = lightPos + halfWidth + halfHeight;
		vec2 uv = LTC_Uv( normal, viewDir, roughness );
		vec4 t1 = texture2D( ltc_1, uv );
		vec4 t2 = texture2D( ltc_2, uv );
		mat3 mInv = mat3(
			vec3( t1.x, 0, t1.y ),
			vec3(    0, 1,    0 ),
			vec3( t1.z, 0, t1.w )
		);
		vec3 fresnel = ( material.specularColor * t2.x + ( vec3( 1.0 ) - material.specularColor ) * t2.y );
		reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate( normal, viewDir, position, mInv, rectCoords );
		reflectedLight.directDiffuse += lightColor * material.diffuseColor * LTC_Evaluate( normal, viewDir, position, mat3( 1.0 ), rectCoords );
	}
#endif
void RE_Direct_Physical( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	#ifdef USE_CLEARCOAT
		float dotNLcc = saturate( dot( geometryClearcoatNormal, directLight.direction ) );
		vec3 ccIrradiance = dotNLcc * directLight.color;
		clearcoatSpecularDirect += ccIrradiance * BRDF_GGX_Clearcoat( directLight.direction, geometryViewDir, geometryClearcoatNormal, material );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularDirect += irradiance * BRDF_Sheen( directLight.direction, geometryViewDir, geometryNormal, material.sheenColor, material.sheenRoughness );
	#endif
	reflectedLight.directSpecular += irradiance * BRDF_GGX( directLight.direction, geometryViewDir, geometryNormal, material );
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Physical( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectSpecular_Physical( const in vec3 radiance, const in vec3 irradiance, const in vec3 clearcoatRadiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	#ifdef USE_CLEARCOAT
		clearcoatSpecularIndirect += clearcoatRadiance * EnvironmentBRDF( geometryClearcoatNormal, geometryViewDir, material.clearcoatF0, material.clearcoatF90, material.clearcoatRoughness );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularIndirect += irradiance * material.sheenColor * IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
	#endif
	vec3 singleScattering = vec3( 0.0 );
	vec3 multiScattering = vec3( 0.0 );
	vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;
	#ifdef USE_IRIDESCENCE
		computeMultiscatteringIridescence( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.iridescence, material.iridescenceFresnel, material.roughness, singleScattering, multiScattering );
	#else
		computeMultiscattering( geometryNormal, geometryViewDir, material.specularColor, material.specularF90, material.roughness, singleScattering, multiScattering );
	#endif
	vec3 totalScattering = singleScattering + multiScattering;
	vec3 diffuse = material.diffuseColor * ( 1.0 - max( max( totalScattering.r, totalScattering.g ), totalScattering.b ) );
	reflectedLight.indirectSpecular += radiance * singleScattering;
	reflectedLight.indirectSpecular += multiScattering * cosineWeightedIrradiance;
	reflectedLight.indirectDiffuse += diffuse * cosineWeightedIrradiance;
}
#define RE_Direct				RE_Direct_Physical
#define RE_Direct_RectArea		RE_Direct_RectArea_Physical
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Physical
#define RE_IndirectSpecular		RE_IndirectSpecular_Physical
float computeSpecularOcclusion( const in float dotNV, const in float ambientOcclusion, const in float roughness ) {
	return saturate( pow( dotNV + ambientOcclusion, exp2( - 16.0 * roughness - 1.0 ) ) - 1.0 + ambientOcclusion );
}`,u_=`
vec3 geometryPosition = - vViewPosition;
vec3 geometryNormal = normal;
vec3 geometryViewDir = ( isOrthographic ) ? vec3( 0, 0, 1 ) : normalize( vViewPosition );
vec3 geometryClearcoatNormal = vec3( 0.0 );
#ifdef USE_CLEARCOAT
	geometryClearcoatNormal = clearcoatNormal;
#endif
#ifdef USE_IRIDESCENCE
	float dotNVi = saturate( dot( normal, geometryViewDir ) );
	if ( material.iridescenceThickness == 0.0 ) {
		material.iridescence = 0.0;
	} else {
		material.iridescence = saturate( material.iridescence );
	}
	if ( material.iridescence > 0.0 ) {
		material.iridescenceFresnel = evalIridescence( 1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness, material.specularColor );
		material.iridescenceF0 = Schlick_to_F0( material.iridescenceFresnel, 1.0, dotNVi );
	}
#endif
IncidentLight directLight;
#if ( NUM_POINT_LIGHTS > 0 ) && defined( RE_Direct )
	PointLight pointLight;
	#if defined( USE_SHADOWMAP ) && NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {
		pointLight = pointLights[ i ];
		getPointLightInfo( pointLight, geometryPosition, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS )
		pointLightShadow = pointLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getPointShadow( pointShadowMap[ i ], pointLightShadow.shadowMapSize, pointLightShadow.shadowIntensity, pointLightShadow.shadowBias, pointLightShadow.shadowRadius, vPointShadowCoord[ i ], pointLightShadow.shadowCameraNear, pointLightShadow.shadowCameraFar ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_SPOT_LIGHTS > 0 ) && defined( RE_Direct )
	SpotLight spotLight;
	vec4 spotColor;
	vec3 spotLightCoord;
	bool inSpotLightMap;
	#if defined( USE_SHADOWMAP ) && NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHTS; i ++ ) {
		spotLight = spotLights[ i ];
		getSpotLightInfo( spotLight, geometryPosition, directLight );
		#if ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#define SPOT_LIGHT_MAP_INDEX UNROLLED_LOOP_INDEX
		#elif ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		#define SPOT_LIGHT_MAP_INDEX NUM_SPOT_LIGHT_MAPS
		#else
		#define SPOT_LIGHT_MAP_INDEX ( UNROLLED_LOOP_INDEX - NUM_SPOT_LIGHT_SHADOWS + NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#endif
		#if ( SPOT_LIGHT_MAP_INDEX < NUM_SPOT_LIGHT_MAPS )
			spotLightCoord = vSpotLightCoord[ i ].xyz / vSpotLightCoord[ i ].w;
			inSpotLightMap = all( lessThan( abs( spotLightCoord * 2. - 1. ), vec3( 1.0 ) ) );
			spotColor = texture2D( spotLightMap[ SPOT_LIGHT_MAP_INDEX ], spotLightCoord.xy );
			directLight.color = inSpotLightMap ? directLight.color * spotColor.rgb : directLight.color;
		#endif
		#undef SPOT_LIGHT_MAP_INDEX
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		spotLightShadow = spotLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( spotShadowMap[ i ], spotLightShadow.shadowMapSize, spotLightShadow.shadowIntensity, spotLightShadow.shadowBias, spotLightShadow.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_DIR_LIGHTS > 0 ) && defined( RE_Direct )
	DirectionalLight directionalLight;
	#if defined( USE_SHADOWMAP ) && NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
		directionalLight = directionalLights[ i ];
		getDirectionalLightInfo( directionalLight, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
		directionalLightShadow = directionalLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( directionalShadowMap[ i ], directionalLightShadow.shadowMapSize, directionalLightShadow.shadowIntensity, directionalLightShadow.shadowBias, directionalLightShadow.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_RECT_AREA_LIGHTS > 0 ) && defined( RE_Direct_RectArea )
	RectAreaLight rectAreaLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_RECT_AREA_LIGHTS; i ++ ) {
		rectAreaLight = rectAreaLights[ i ];
		RE_Direct_RectArea( rectAreaLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if defined( RE_IndirectDiffuse )
	vec3 iblIrradiance = vec3( 0.0 );
	vec3 irradiance = getAmbientLightIrradiance( ambientLightColor );
	#if defined( USE_LIGHT_PROBES )
		irradiance += getLightProbeIrradiance( lightProbe, geometryNormal );
	#endif
	#if ( NUM_HEMI_LIGHTS > 0 )
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_HEMI_LIGHTS; i ++ ) {
			irradiance += getHemisphereLightIrradiance( hemisphereLights[ i ], geometryNormal );
		}
		#pragma unroll_loop_end
	#endif
#endif
#if defined( RE_IndirectSpecular )
	vec3 radiance = vec3( 0.0 );
	vec3 clearcoatRadiance = vec3( 0.0 );
#endif`,h_=`#if defined( RE_IndirectDiffuse )
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		vec3 lightMapIrradiance = lightMapTexel.rgb * lightMapIntensity;
		irradiance += lightMapIrradiance;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD ) && defined( ENVMAP_TYPE_CUBE_UV )
		iblIrradiance += getIBLIrradiance( geometryNormal );
	#endif
#endif
#if defined( USE_ENVMAP ) && defined( RE_IndirectSpecular )
	#ifdef USE_ANISOTROPY
		radiance += getIBLAnisotropyRadiance( geometryViewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy );
	#else
		radiance += getIBLRadiance( geometryViewDir, geometryNormal, material.roughness );
	#endif
	#ifdef USE_CLEARCOAT
		clearcoatRadiance += getIBLRadiance( geometryViewDir, geometryClearcoatNormal, material.clearcoatRoughness );
	#endif
#endif`,f_=`#if defined( RE_IndirectDiffuse )
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,d_=`#if defined( USE_LOGDEPTHBUF )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,p_=`#if defined( USE_LOGDEPTHBUF )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,m_=`#ifdef USE_LOGDEPTHBUF
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,g_=`#ifdef USE_LOGDEPTHBUF
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,v_=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = vec4( mix( pow( sampledDiffuseColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), sampledDiffuseColor.rgb * 0.0773993808, vec3( lessThanEqual( sampledDiffuseColor.rgb, vec3( 0.04045 ) ) ) ), sampledDiffuseColor.w );
	
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,__=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,x_=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
	#if defined( USE_POINTS_UV )
		vec2 uv = vUv;
	#else
		vec2 uv = ( uvTransform * vec3( gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1 ) ).xy;
	#endif
#endif
#ifdef USE_MAP
	diffuseColor *= texture2D( map, uv );
#endif
#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, uv ).g;
#endif`,y_=`#if defined( USE_POINTS_UV )
	varying vec2 vUv;
#else
	#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
		uniform mat3 uvTransform;
	#endif
#endif
#ifdef USE_MAP
	uniform sampler2D map;
#endif
#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,S_=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,M_=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,b_=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,w_=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,E_=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,T_=`#ifdef USE_MORPHTARGETS
	#ifndef USE_INSTANCING_MORPH
		uniform float morphTargetBaseInfluence;
		uniform float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	#endif
	uniform sampler2DArray morphTargetsTexture;
	uniform ivec2 morphTargetsTextureSize;
	vec4 getMorph( const in int vertexIndex, const in int morphTargetIndex, const in int offset ) {
		int texelIndex = vertexIndex * MORPHTARGETS_TEXTURE_STRIDE + offset;
		int y = texelIndex / morphTargetsTextureSize.x;
		int x = texelIndex - y * morphTargetsTextureSize.x;
		ivec3 morphUV = ivec3( x, y, morphTargetIndex );
		return texelFetch( morphTargetsTexture, morphUV, 0 );
	}
#endif`,A_=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,C_=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
#ifdef FLAT_SHADED
	vec3 fdx = dFdx( vViewPosition );
	vec3 fdy = dFdy( vViewPosition );
	vec3 normal = normalize( cross( fdx, fdy ) );
#else
	vec3 normal = normalize( vNormal );
	#ifdef DOUBLE_SIDED
		normal *= faceDirection;
	#endif
#endif
#if defined( USE_NORMALMAP_TANGENTSPACE ) || defined( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY )
	#ifdef USE_TANGENT
		mat3 tbn = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn = getTangentFrame( - vViewPosition, normal,
		#if defined( USE_NORMALMAP )
			vNormalMapUv
		#elif defined( USE_CLEARCOAT_NORMALMAP )
			vClearcoatNormalMapUv
		#else
			vUv
		#endif
		);
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn[0] *= faceDirection;
		tbn[1] *= faceDirection;
	#endif
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	#ifdef USE_TANGENT
		mat3 tbn2 = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn2 = getTangentFrame( - vViewPosition, normal, vClearcoatNormalMapUv );
	#endif
	#if defined( DOUBLE_SIDED ) && ! defined( FLAT_SHADED )
		tbn2[0] *= faceDirection;
		tbn2[1] *= faceDirection;
	#endif
#endif
vec3 nonPerturbedNormal = normal;`,R_=`#ifdef USE_NORMALMAP_OBJECTSPACE
	normal = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	#ifdef FLIP_SIDED
		normal = - normal;
	#endif
	#ifdef DOUBLE_SIDED
		normal = normal * faceDirection;
	#endif
	normal = normalize( normalMatrix * normal );
#elif defined( USE_NORMALMAP_TANGENTSPACE )
	vec3 mapN = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	mapN.xy *= normalScale;
	normal = normalize( tbn * mapN );
#elif defined( USE_BUMPMAP )
	normal = perturbNormalArb( - vViewPosition, normal, dHdxy_fwd(), faceDirection );
#endif`,P_=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,L_=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,D_=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
	#endif
#endif`,I_=`#ifdef USE_NORMALMAP
	uniform sampler2D normalMap;
	uniform vec2 normalScale;
#endif
#ifdef USE_NORMALMAP_OBJECTSPACE
	uniform mat3 normalMatrix;
#endif
#if ! defined ( USE_TANGENT ) && ( defined ( USE_NORMALMAP_TANGENTSPACE ) || defined ( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY ) )
	mat3 getTangentFrame( vec3 eye_pos, vec3 surf_norm, vec2 uv ) {
		vec3 q0 = dFdx( eye_pos.xyz );
		vec3 q1 = dFdy( eye_pos.xyz );
		vec2 st0 = dFdx( uv.st );
		vec2 st1 = dFdy( uv.st );
		vec3 N = surf_norm;
		vec3 q1perp = cross( q1, N );
		vec3 q0perp = cross( N, q0 );
		vec3 T = q1perp * st0.x + q0perp * st1.x;
		vec3 B = q1perp * st0.y + q0perp * st1.y;
		float det = max( dot( T, T ), dot( B, B ) );
		float scale = ( det == 0.0 ) ? 0.0 : inversesqrt( det );
		return mat3( T * scale, B * scale, N );
	}
#endif`,U_=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,N_=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,F_=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,O_=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,k_=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,B_=`vec3 packNormalToRGB( const in vec3 normal ) {
	return normalize( normal ) * 0.5 + 0.5;
}
vec3 unpackRGBToNormal( const in vec3 rgb ) {
	return 2.0 * rgb.xyz - 1.0;
}
const float PackUpscale = 256. / 255.;const float UnpackDownscale = 255. / 256.;const float ShiftRight8 = 1. / 256.;
const float Inv255 = 1. / 255.;
const vec4 PackFactors = vec4( 1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0 );
const vec2 UnpackFactors2 = vec2( UnpackDownscale, 1.0 / PackFactors.g );
const vec3 UnpackFactors3 = vec3( UnpackDownscale / PackFactors.rg, 1.0 / PackFactors.b );
const vec4 UnpackFactors4 = vec4( UnpackDownscale / PackFactors.rgb, 1.0 / PackFactors.a );
vec4 packDepthToRGBA( const in float v ) {
	if( v <= 0.0 )
		return vec4( 0., 0., 0., 0. );
	if( v >= 1.0 )
		return vec4( 1., 1., 1., 1. );
	float vuf;
	float af = modf( v * PackFactors.a, vuf );
	float bf = modf( vuf * ShiftRight8, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec4( vuf * Inv255, gf * PackUpscale, bf * PackUpscale, af );
}
vec3 packDepthToRGB( const in float v ) {
	if( v <= 0.0 )
		return vec3( 0., 0., 0. );
	if( v >= 1.0 )
		return vec3( 1., 1., 1. );
	float vuf;
	float bf = modf( v * PackFactors.b, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec3( vuf * Inv255, gf * PackUpscale, bf );
}
vec2 packDepthToRG( const in float v ) {
	if( v <= 0.0 )
		return vec2( 0., 0. );
	if( v >= 1.0 )
		return vec2( 1., 1. );
	float vuf;
	float gf = modf( v * 256., vuf );
	return vec2( vuf * Inv255, gf );
}
float unpackRGBAToDepth( const in vec4 v ) {
	return dot( v, UnpackFactors4 );
}
float unpackRGBToDepth( const in vec3 v ) {
	return dot( v, UnpackFactors3 );
}
float unpackRGToDepth( const in vec2 v ) {
	return v.r * UnpackFactors2.r + v.g * UnpackFactors2.g;
}
vec4 pack2HalfToRGBA( const in vec2 v ) {
	vec4 r = vec4( v.x, fract( v.x * 255.0 ), v.y, fract( v.y * 255.0 ) );
	return vec4( r.x - r.y / 255.0, r.y, r.z - r.w / 255.0, r.w );
}
vec2 unpackRGBATo2Half( const in vec4 v ) {
	return vec2( v.x + ( v.y / 255.0 ), v.z + ( v.w / 255.0 ) );
}
float viewZToOrthographicDepth( const in float viewZ, const in float near, const in float far ) {
	return ( viewZ + near ) / ( near - far );
}
float orthographicDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return depth * ( near - far ) - near;
}
float viewZToPerspectiveDepth( const in float viewZ, const in float near, const in float far ) {
	return ( ( near + viewZ ) * far ) / ( ( far - near ) * viewZ );
}
float perspectiveDepthToViewZ( const in float depth, const in float near, const in float far ) {
	return ( near * far ) / ( ( far - near ) * depth - far );
}`,z_=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,H_=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,G_=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,V_=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,W_=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,X_=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,q_=`#if NUM_SPOT_LIGHT_COORDS > 0
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#if NUM_SPOT_LIGHT_MAPS > 0
	uniform sampler2D spotLightMap[ NUM_SPOT_LIGHT_MAPS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		uniform sampler2D spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform sampler2D pointShadowMap[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
	float texture2DCompare( sampler2D depths, vec2 uv, float compare ) {
		return step( compare, unpackRGBAToDepth( texture2D( depths, uv ) ) );
	}
	vec2 texture2DDistribution( sampler2D shadow, vec2 uv ) {
		return unpackRGBATo2Half( texture2D( shadow, uv ) );
	}
	float VSMShadow (sampler2D shadow, vec2 uv, float compare ){
		float occlusion = 1.0;
		vec2 distribution = texture2DDistribution( shadow, uv );
		float hard_shadow = step( compare , distribution.x );
		if (hard_shadow != 1.0 ) {
			float distance = compare - distribution.x ;
			float variance = max( 0.00000, distribution.y * distribution.y );
			float softness_probability = variance / (variance + distance * distance );			softness_probability = clamp( ( softness_probability - 0.3 ) / ( 0.95 - 0.3 ), 0.0, 1.0 );			occlusion = clamp( max( hard_shadow, softness_probability ), 0.0, 1.0 );
		}
		return occlusion;
	}
	float getShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
		float shadow = 1.0;
		shadowCoord.xyz /= shadowCoord.w;
		shadowCoord.z += shadowBias;
		bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
		bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
		if ( frustumTest ) {
		#if defined( SHADOWMAP_TYPE_PCF )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx0 = - texelSize.x * shadowRadius;
			float dy0 = - texelSize.y * shadowRadius;
			float dx1 = + texelSize.x * shadowRadius;
			float dy1 = + texelSize.y * shadowRadius;
			float dx2 = dx0 / 2.0;
			float dy2 = dy0 / 2.0;
			float dx3 = dx1 / 2.0;
			float dy3 = dy1 / 2.0;
			shadow = (
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy2 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx2, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx3, dy3 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( 0.0, dy1 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, shadowCoord.xy + vec2( dx1, dy1 ), shadowCoord.z )
			) * ( 1.0 / 17.0 );
		#elif defined( SHADOWMAP_TYPE_PCF_SOFT )
			vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
			float dx = texelSize.x;
			float dy = texelSize.y;
			vec2 uv = shadowCoord.xy;
			vec2 f = fract( uv * shadowMapSize + 0.5 );
			uv -= f * texelSize;
			shadow = (
				texture2DCompare( shadowMap, uv, shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( dx, 0.0 ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + vec2( 0.0, dy ), shadowCoord.z ) +
				texture2DCompare( shadowMap, uv + texelSize, shadowCoord.z ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, 0.0 ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 0.0 ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( -dx, dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, dy ), shadowCoord.z ),
					 f.x ) +
				mix( texture2DCompare( shadowMap, uv + vec2( 0.0, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( 0.0, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( texture2DCompare( shadowMap, uv + vec2( dx, -dy ), shadowCoord.z ),
					 texture2DCompare( shadowMap, uv + vec2( dx, 2.0 * dy ), shadowCoord.z ),
					 f.y ) +
				mix( mix( texture2DCompare( shadowMap, uv + vec2( -dx, -dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, -dy ), shadowCoord.z ),
						  f.x ),
					 mix( texture2DCompare( shadowMap, uv + vec2( -dx, 2.0 * dy ), shadowCoord.z ),
						  texture2DCompare( shadowMap, uv + vec2( 2.0 * dx, 2.0 * dy ), shadowCoord.z ),
						  f.x ),
					 f.y )
			) * ( 1.0 / 9.0 );
		#elif defined( SHADOWMAP_TYPE_VSM )
			shadow = VSMShadow( shadowMap, shadowCoord.xy, shadowCoord.z );
		#else
			shadow = texture2DCompare( shadowMap, shadowCoord.xy, shadowCoord.z );
		#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
	vec2 cubeToUV( vec3 v, float texelSizeY ) {
		vec3 absV = abs( v );
		float scaleToCube = 1.0 / max( absV.x, max( absV.y, absV.z ) );
		absV *= scaleToCube;
		v *= scaleToCube * ( 1.0 - 2.0 * texelSizeY );
		vec2 planar = v.xy;
		float almostATexel = 1.5 * texelSizeY;
		float almostOne = 1.0 - almostATexel;
		if ( absV.z >= almostOne ) {
			if ( v.z > 0.0 )
				planar.x = 4.0 - v.x;
		} else if ( absV.x >= almostOne ) {
			float signX = sign( v.x );
			planar.x = v.z * signX + 2.0 * signX;
		} else if ( absV.y >= almostOne ) {
			float signY = sign( v.y );
			planar.x = v.x + 2.0 * signY + 2.0;
			planar.y = v.z * signY - 2.0;
		}
		return vec2( 0.125, 0.25 ) * planar + vec2( 0.375, 0.75 );
	}
	float getPointShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord, float shadowCameraNear, float shadowCameraFar ) {
		float shadow = 1.0;
		vec3 lightToPosition = shadowCoord.xyz;
		
		float lightToPositionLength = length( lightToPosition );
		if ( lightToPositionLength - shadowCameraFar <= 0.0 && lightToPositionLength - shadowCameraNear >= 0.0 ) {
			float dp = ( lightToPositionLength - shadowCameraNear ) / ( shadowCameraFar - shadowCameraNear );			dp += shadowBias;
			vec3 bd3D = normalize( lightToPosition );
			vec2 texelSize = vec2( 1.0 ) / ( shadowMapSize * vec2( 4.0, 2.0 ) );
			#if defined( SHADOWMAP_TYPE_PCF ) || defined( SHADOWMAP_TYPE_PCF_SOFT ) || defined( SHADOWMAP_TYPE_VSM )
				vec2 offset = vec2( - 1, 1 ) * shadowRadius * texelSize.y;
				shadow = (
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yyx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxy, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.xxx, texelSize.y ), dp ) +
					texture2DCompare( shadowMap, cubeToUV( bd3D + offset.yxx, texelSize.y ), dp )
				) * ( 1.0 / 9.0 );
			#else
				shadow = texture2DCompare( shadowMap, cubeToUV( bd3D, texelSize.y ), dp );
			#endif
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
#endif`,$_=`#if NUM_SPOT_LIGHT_COORDS > 0
	uniform mat4 spotLightMatrix[ NUM_SPOT_LIGHT_COORDS ];
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform mat4 directionalShadowMatrix[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform mat4 pointShadowMatrix[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
#endif`,Y_=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
	vec3 shadowWorldNormal = inverseTransformDirection( transformedNormal, viewMatrix );
	vec4 shadowWorldPosition;
#endif
#if defined( USE_SHADOWMAP )
	#if NUM_DIR_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * directionalLightShadows[ i ].shadowNormalBias, 0 );
			vDirectionalShadowCoord[ i ] = directionalShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * pointLightShadows[ i ].shadowNormalBias, 0 );
			vPointShadowCoord[ i ] = pointShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
#endif
#if NUM_SPOT_LIGHT_COORDS > 0
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_COORDS; i ++ ) {
		shadowWorldPosition = worldPosition;
		#if ( defined( USE_SHADOWMAP ) && UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
			shadowWorldPosition.xyz += shadowWorldNormal * spotLightShadows[ i ].shadowNormalBias;
		#endif
		vSpotLightCoord[ i ] = spotLightMatrix[ i ] * shadowWorldPosition;
	}
	#pragma unroll_loop_end
#endif`,K_=`float getShadowMask() {
	float shadow = 1.0;
	#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
		directionalLight = directionalLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowIntensity, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_SHADOWS; i ++ ) {
		spotLight = spotLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( spotShadowMap[ i ], spotLight.shadowMapSize, spotLight.shadowIntensity, spotLight.shadowBias, spotLight.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
		pointLight = pointLightShadows[ i ];
		shadow *= receiveShadow ? getPointShadow( pointShadowMap[ i ], pointLight.shadowMapSize, pointLight.shadowIntensity, pointLight.shadowBias, pointLight.shadowRadius, vPointShadowCoord[ i ], pointLight.shadowCameraNear, pointLight.shadowCameraFar ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#endif
	return shadow;
}`,j_=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,Z_=`#ifdef USE_SKINNING
	uniform mat4 bindMatrix;
	uniform mat4 bindMatrixInverse;
	uniform highp sampler2D boneTexture;
	mat4 getBoneMatrix( const in float i ) {
		int size = textureSize( boneTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( boneTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( boneTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( boneTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( boneTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
#endif`,J_=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,Q_=`#ifdef USE_SKINNING
	mat4 skinMatrix = mat4( 0.0 );
	skinMatrix += skinWeight.x * boneMatX;
	skinMatrix += skinWeight.y * boneMatY;
	skinMatrix += skinWeight.z * boneMatZ;
	skinMatrix += skinWeight.w * boneMatW;
	skinMatrix = bindMatrixInverse * skinMatrix * bindMatrix;
	objectNormal = vec4( skinMatrix * vec4( objectNormal, 0.0 ) ).xyz;
	#ifdef USE_TANGENT
		objectTangent = vec4( skinMatrix * vec4( objectTangent, 0.0 ) ).xyz;
	#endif
#endif`,e1=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,t1=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,n1=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,i1=`#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
uniform float toneMappingExposure;
vec3 LinearToneMapping( vec3 color ) {
	return saturate( toneMappingExposure * color );
}
vec3 ReinhardToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	return saturate( color / ( vec3( 1.0 ) + color ) );
}
vec3 CineonToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	color = max( vec3( 0.0 ), color - 0.004 );
	return pow( ( color * ( 6.2 * color + 0.5 ) ) / ( color * ( 6.2 * color + 1.7 ) + 0.06 ), vec3( 2.2 ) );
}
vec3 RRTAndODTFit( vec3 v ) {
	vec3 a = v * ( v + 0.0245786 ) - 0.000090537;
	vec3 b = v * ( 0.983729 * v + 0.4329510 ) + 0.238081;
	return a / b;
}
vec3 ACESFilmicToneMapping( vec3 color ) {
	const mat3 ACESInputMat = mat3(
		vec3( 0.59719, 0.07600, 0.02840 ),		vec3( 0.35458, 0.90834, 0.13383 ),
		vec3( 0.04823, 0.01566, 0.83777 )
	);
	const mat3 ACESOutputMat = mat3(
		vec3(  1.60475, -0.10208, -0.00327 ),		vec3( -0.53108,  1.10813, -0.07276 ),
		vec3( -0.07367, -0.00605,  1.07602 )
	);
	color *= toneMappingExposure / 0.6;
	color = ACESInputMat * color;
	color = RRTAndODTFit( color );
	color = ACESOutputMat * color;
	return saturate( color );
}
const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
	vec3( 1.6605, - 0.1246, - 0.0182 ),
	vec3( - 0.5876, 1.1329, - 0.1006 ),
	vec3( - 0.0728, - 0.0083, 1.1187 )
);
const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
	vec3( 0.6274, 0.0691, 0.0164 ),
	vec3( 0.3293, 0.9195, 0.0880 ),
	vec3( 0.0433, 0.0113, 0.8956 )
);
vec3 agxDefaultContrastApprox( vec3 x ) {
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return + 15.5 * x4 * x2
		- 40.14 * x4 * x
		+ 31.96 * x4
		- 6.868 * x2 * x
		+ 0.4298 * x2
		+ 0.1191 * x
		- 0.00232;
}
vec3 AgXToneMapping( vec3 color ) {
	const mat3 AgXInsetMatrix = mat3(
		vec3( 0.856627153315983, 0.137318972929847, 0.11189821299995 ),
		vec3( 0.0951212405381588, 0.761241990602591, 0.0767994186031903 ),
		vec3( 0.0482516061458583, 0.101439036467562, 0.811302368396859 )
	);
	const mat3 AgXOutsetMatrix = mat3(
		vec3( 1.1271005818144368, - 0.1413297634984383, - 0.14132976349843826 ),
		vec3( - 0.11060664309660323, 1.157823702216272, - 0.11060664309660294 ),
		vec3( - 0.016493938717834573, - 0.016493938717834257, 1.2519364065950405 )
	);
	const float AgxMinEv = - 12.47393;	const float AgxMaxEv = 4.026069;
	color *= toneMappingExposure;
	color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
	color = AgXInsetMatrix * color;
	color = max( color, 1e-10 );	color = log2( color );
	color = ( color - AgxMinEv ) / ( AgxMaxEv - AgxMinEv );
	color = clamp( color, 0.0, 1.0 );
	color = agxDefaultContrastApprox( color );
	color = AgXOutsetMatrix * color;
	color = pow( max( vec3( 0.0 ), color ), vec3( 2.2 ) );
	color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
	color = clamp( color, 0.0, 1.0 );
	return color;
}
vec3 NeutralToneMapping( vec3 color ) {
	const float StartCompression = 0.8 - 0.04;
	const float Desaturation = 0.15;
	color *= toneMappingExposure;
	float x = min( color.r, min( color.g, color.b ) );
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max( color.r, max( color.g, color.b ) );
	if ( peak < StartCompression ) return color;
	float d = 1. - StartCompression;
	float newPeak = 1. - d * d / ( peak + d - StartCompression );
	color *= newPeak / peak;
	float g = 1. - 1. / ( Desaturation * ( peak - newPeak ) + 1. );
	return mix( color, vec3( newPeak ), g );
}
vec3 CustomToneMapping( vec3 color ) { return color; }`,r1=`#ifdef USE_TRANSMISSION
	material.transmission = transmission;
	material.transmissionAlpha = 1.0;
	material.thickness = thickness;
	material.attenuationDistance = attenuationDistance;
	material.attenuationColor = attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		material.transmission *= texture2D( transmissionMap, vTransmissionMapUv ).r;
	#endif
	#ifdef USE_THICKNESSMAP
		material.thickness *= texture2D( thicknessMap, vThicknessMapUv ).g;
	#endif
	vec3 pos = vWorldPosition;
	vec3 v = normalize( cameraPosition - pos );
	vec3 n = inverseTransformDirection( normal, viewMatrix );
	vec4 transmitted = getIBLVolumeRefraction(
		n, v, material.roughness, material.diffuseColor, material.specularColor, material.specularF90,
		pos, modelMatrix, viewMatrix, projectionMatrix, material.dispersion, material.ior, material.thickness,
		material.attenuationColor, material.attenuationDistance );
	material.transmissionAlpha = mix( material.transmissionAlpha, transmitted.a, material.transmission );
	totalDiffuse = mix( totalDiffuse, transmitted.rgb, material.transmission );
#endif`,s1=`#ifdef USE_TRANSMISSION
	uniform float transmission;
	uniform float thickness;
	uniform float attenuationDistance;
	uniform vec3 attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		uniform sampler2D transmissionMap;
	#endif
	#ifdef USE_THICKNESSMAP
		uniform sampler2D thicknessMap;
	#endif
	uniform vec2 transmissionSamplerSize;
	uniform sampler2D transmissionSamplerMap;
	uniform mat4 modelMatrix;
	uniform mat4 projectionMatrix;
	varying vec3 vWorldPosition;
	float w0( float a ) {
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - a + 3.0 ) - 3.0 ) + 1.0 );
	}
	float w1( float a ) {
		return ( 1.0 / 6.0 ) * ( a *  a * ( 3.0 * a - 6.0 ) + 4.0 );
	}
	float w2( float a ){
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - 3.0 * a + 3.0 ) + 3.0 ) + 1.0 );
	}
	float w3( float a ) {
		return ( 1.0 / 6.0 ) * ( a * a * a );
	}
	float g0( float a ) {
		return w0( a ) + w1( a );
	}
	float g1( float a ) {
		return w2( a ) + w3( a );
	}
	float h0( float a ) {
		return - 1.0 + w1( a ) / ( w0( a ) + w1( a ) );
	}
	float h1( float a ) {
		return 1.0 + w3( a ) / ( w2( a ) + w3( a ) );
	}
	vec4 bicubic( sampler2D tex, vec2 uv, vec4 texelSize, float lod ) {
		uv = uv * texelSize.zw + 0.5;
		vec2 iuv = floor( uv );
		vec2 fuv = fract( uv );
		float g0x = g0( fuv.x );
		float g1x = g1( fuv.x );
		float h0x = h0( fuv.x );
		float h1x = h1( fuv.x );
		float h0y = h0( fuv.y );
		float h1y = h1( fuv.y );
		vec2 p0 = ( vec2( iuv.x + h0x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p1 = ( vec2( iuv.x + h1x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p2 = ( vec2( iuv.x + h0x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		vec2 p3 = ( vec2( iuv.x + h1x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		return g0( fuv.y ) * ( g0x * textureLod( tex, p0, lod ) + g1x * textureLod( tex, p1, lod ) ) +
			g1( fuv.y ) * ( g0x * textureLod( tex, p2, lod ) + g1x * textureLod( tex, p3, lod ) );
	}
	vec4 textureBicubic( sampler2D sampler, vec2 uv, float lod ) {
		vec2 fLodSize = vec2( textureSize( sampler, int( lod ) ) );
		vec2 cLodSize = vec2( textureSize( sampler, int( lod + 1.0 ) ) );
		vec2 fLodSizeInv = 1.0 / fLodSize;
		vec2 cLodSizeInv = 1.0 / cLodSize;
		vec4 fSample = bicubic( sampler, uv, vec4( fLodSizeInv, fLodSize ), floor( lod ) );
		vec4 cSample = bicubic( sampler, uv, vec4( cLodSizeInv, cLodSize ), ceil( lod ) );
		return mix( fSample, cSample, fract( lod ) );
	}
	vec3 getVolumeTransmissionRay( const in vec3 n, const in vec3 v, const in float thickness, const in float ior, const in mat4 modelMatrix ) {
		vec3 refractionVector = refract( - v, normalize( n ), 1.0 / ior );
		vec3 modelScale;
		modelScale.x = length( vec3( modelMatrix[ 0 ].xyz ) );
		modelScale.y = length( vec3( modelMatrix[ 1 ].xyz ) );
		modelScale.z = length( vec3( modelMatrix[ 2 ].xyz ) );
		return normalize( refractionVector ) * thickness * modelScale;
	}
	float applyIorToRoughness( const in float roughness, const in float ior ) {
		return roughness * clamp( ior * 2.0 - 2.0, 0.0, 1.0 );
	}
	vec4 getTransmissionSample( const in vec2 fragCoord, const in float roughness, const in float ior ) {
		float lod = log2( transmissionSamplerSize.x ) * applyIorToRoughness( roughness, ior );
		return textureBicubic( transmissionSamplerMap, fragCoord.xy, lod );
	}
	vec3 volumeAttenuation( const in float transmissionDistance, const in vec3 attenuationColor, const in float attenuationDistance ) {
		if ( isinf( attenuationDistance ) ) {
			return vec3( 1.0 );
		} else {
			vec3 attenuationCoefficient = -log( attenuationColor ) / attenuationDistance;
			vec3 transmittance = exp( - attenuationCoefficient * transmissionDistance );			return transmittance;
		}
	}
	vec4 getIBLVolumeRefraction( const in vec3 n, const in vec3 v, const in float roughness, const in vec3 diffuseColor,
		const in vec3 specularColor, const in float specularF90, const in vec3 position, const in mat4 modelMatrix,
		const in mat4 viewMatrix, const in mat4 projMatrix, const in float dispersion, const in float ior, const in float thickness,
		const in vec3 attenuationColor, const in float attenuationDistance ) {
		vec4 transmittedLight;
		vec3 transmittance;
		#ifdef USE_DISPERSION
			float halfSpread = ( ior - 1.0 ) * 0.025 * dispersion;
			vec3 iors = vec3( ior - halfSpread, ior, ior + halfSpread );
			for ( int i = 0; i < 3; i ++ ) {
				vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, iors[ i ], modelMatrix );
				vec3 refractedRayExit = position + transmissionRay;
		
				vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
				vec2 refractionCoords = ndcPos.xy / ndcPos.w;
				refractionCoords += 1.0;
				refractionCoords /= 2.0;
		
				vec4 transmissionSample = getTransmissionSample( refractionCoords, roughness, iors[ i ] );
				transmittedLight[ i ] = transmissionSample[ i ];
				transmittedLight.a += transmissionSample.a;
				transmittance[ i ] = diffuseColor[ i ] * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance )[ i ];
			}
			transmittedLight.a /= 3.0;
		
		#else
		
			vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, ior, modelMatrix );
			vec3 refractedRayExit = position + transmissionRay;
			vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
			vec2 refractionCoords = ndcPos.xy / ndcPos.w;
			refractionCoords += 1.0;
			refractionCoords /= 2.0;
			transmittedLight = getTransmissionSample( refractionCoords, roughness, ior );
			transmittance = diffuseColor * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance );
		
		#endif
		vec3 attenuatedColor = transmittance * transmittedLight.rgb;
		vec3 F = EnvironmentBRDF( n, v, specularColor, specularF90, roughness );
		float transmittanceFactor = ( transmittance.r + transmittance.g + transmittance.b ) / 3.0;
		return vec4( ( 1.0 - F ) * attenuatedColor, 1.0 - ( 1.0 - transmittedLight.a ) * transmittanceFactor );
	}
#endif`,o1=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_SPECULARMAP
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,a1=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	uniform mat3 mapTransform;
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	uniform mat3 alphaMapTransform;
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	uniform mat3 lightMapTransform;
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	uniform mat3 aoMapTransform;
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	uniform mat3 bumpMapTransform;
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	uniform mat3 normalMapTransform;
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_DISPLACEMENTMAP
	uniform mat3 displacementMapTransform;
	varying vec2 vDisplacementMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	uniform mat3 emissiveMapTransform;
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	uniform mat3 metalnessMapTransform;
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	uniform mat3 roughnessMapTransform;
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	uniform mat3 anisotropyMapTransform;
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	uniform mat3 clearcoatMapTransform;
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform mat3 clearcoatNormalMapTransform;
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform mat3 clearcoatRoughnessMapTransform;
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	uniform mat3 sheenColorMapTransform;
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	uniform mat3 sheenRoughnessMapTransform;
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	uniform mat3 iridescenceMapTransform;
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform mat3 iridescenceThicknessMapTransform;
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SPECULARMAP
	uniform mat3 specularMapTransform;
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	uniform mat3 specularColorMapTransform;
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	uniform mat3 specularIntensityMapTransform;
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,l1=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	vUv = vec3( uv, 1 ).xy;
#endif
#ifdef USE_MAP
	vMapUv = ( mapTransform * vec3( MAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ALPHAMAP
	vAlphaMapUv = ( alphaMapTransform * vec3( ALPHAMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_LIGHTMAP
	vLightMapUv = ( lightMapTransform * vec3( LIGHTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_AOMAP
	vAoMapUv = ( aoMapTransform * vec3( AOMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_BUMPMAP
	vBumpMapUv = ( bumpMapTransform * vec3( BUMPMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_NORMALMAP
	vNormalMapUv = ( normalMapTransform * vec3( NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_DISPLACEMENTMAP
	vDisplacementMapUv = ( displacementMapTransform * vec3( DISPLACEMENTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_EMISSIVEMAP
	vEmissiveMapUv = ( emissiveMapTransform * vec3( EMISSIVEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_METALNESSMAP
	vMetalnessMapUv = ( metalnessMapTransform * vec3( METALNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ROUGHNESSMAP
	vRoughnessMapUv = ( roughnessMapTransform * vec3( ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ANISOTROPYMAP
	vAnisotropyMapUv = ( anisotropyMapTransform * vec3( ANISOTROPYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOATMAP
	vClearcoatMapUv = ( clearcoatMapTransform * vec3( CLEARCOATMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	vClearcoatNormalMapUv = ( clearcoatNormalMapTransform * vec3( CLEARCOAT_NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	vClearcoatRoughnessMapUv = ( clearcoatRoughnessMapTransform * vec3( CLEARCOAT_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCEMAP
	vIridescenceMapUv = ( iridescenceMapTransform * vec3( IRIDESCENCEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	vIridescenceThicknessMapUv = ( iridescenceThicknessMapTransform * vec3( IRIDESCENCE_THICKNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_COLORMAP
	vSheenColorMapUv = ( sheenColorMapTransform * vec3( SHEEN_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	vSheenRoughnessMapUv = ( sheenRoughnessMapTransform * vec3( SHEEN_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULARMAP
	vSpecularMapUv = ( specularMapTransform * vec3( SPECULARMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_COLORMAP
	vSpecularColorMapUv = ( specularColorMapTransform * vec3( SPECULAR_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	vSpecularIntensityMapUv = ( specularIntensityMapTransform * vec3( SPECULAR_INTENSITYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_TRANSMISSIONMAP
	vTransmissionMapUv = ( transmissionMapTransform * vec3( TRANSMISSIONMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_THICKNESSMAP
	vThicknessMapUv = ( thicknessMapTransform * vec3( THICKNESSMAP_UV, 1 ) ).xy;
#endif`,c1=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`;const u1=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,h1=`uniform sampler2D t2D;
uniform float backgroundIntensity;
varying vec2 vUv;
void main() {
	vec4 texColor = texture2D( t2D, vUv );
	#ifdef DECODE_VIDEO_TEXTURE
		texColor = vec4( mix( pow( texColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), texColor.rgb * 0.0773993808, vec3( lessThanEqual( texColor.rgb, vec3( 0.04045 ) ) ) ), texColor.w );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,f1=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,d1=`#ifdef ENVMAP_TYPE_CUBE
	uniform samplerCube envMap;
#elif defined( ENVMAP_TYPE_CUBE_UV )
	uniform sampler2D envMap;
#endif
uniform float flipEnvMap;
uniform float backgroundBlurriness;
uniform float backgroundIntensity;
uniform mat3 backgroundRotation;
varying vec3 vWorldDirection;
#include <cube_uv_reflection_fragment>
void main() {
	#ifdef ENVMAP_TYPE_CUBE
		vec4 texColor = textureCube( envMap, backgroundRotation * vec3( flipEnvMap * vWorldDirection.x, vWorldDirection.yz ) );
	#elif defined( ENVMAP_TYPE_CUBE_UV )
		vec4 texColor = textureCubeUV( envMap, backgroundRotation * vWorldDirection, backgroundBlurriness );
	#else
		vec4 texColor = vec4( 0.0, 0.0, 0.0, 1.0 );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,p1=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,m1=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,g1=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
varying vec2 vHighPrecisionZW;
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vHighPrecisionZW = gl_Position.zw;
}`,v1=`#if DEPTH_PACKING == 3200
	uniform float opacity;
#endif
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
varying vec2 vHighPrecisionZW;
void main() {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#if DEPTH_PACKING == 3200
		diffuseColor.a = opacity;
	#endif
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <logdepthbuf_fragment>
	float fragCoordZ = 0.5 * vHighPrecisionZW[0] / vHighPrecisionZW[1] + 0.5;
	#if DEPTH_PACKING == 3200
		gl_FragColor = vec4( vec3( 1.0 - fragCoordZ ), opacity );
	#elif DEPTH_PACKING == 3201
		gl_FragColor = packDepthToRGBA( fragCoordZ );
	#elif DEPTH_PACKING == 3202
		gl_FragColor = vec4( packDepthToRGB( fragCoordZ ), 1.0 );
	#elif DEPTH_PACKING == 3203
		gl_FragColor = vec4( packDepthToRG( fragCoordZ ), 0.0, 1.0 );
	#endif
}`,_1=`#define DISTANCE
varying vec3 vWorldPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <worldpos_vertex>
	#include <clipping_planes_vertex>
	vWorldPosition = worldPosition.xyz;
}`,x1=`#define DISTANCE
uniform vec3 referencePosition;
uniform float nearDistance;
uniform float farDistance;
varying vec3 vWorldPosition;
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <clipping_planes_pars_fragment>
void main () {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	float dist = length( vWorldPosition - referencePosition );
	dist = ( dist - nearDistance ) / ( farDistance - nearDistance );
	dist = saturate( dist );
	gl_FragColor = packDepthToRGBA( dist );
}`,y1=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,S1=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,M1=`uniform float scale;
attribute float lineDistance;
varying float vLineDistance;
#include <common>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	vLineDistance = scale * lineDistance;
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,b1=`uniform vec3 diffuse;
uniform float opacity;
uniform float dashSize;
uniform float totalSize;
varying float vLineDistance;
#include <common>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	if ( mod( vLineDistance, totalSize ) > dashSize ) {
		discard;
	}
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,w1=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#if defined ( USE_ENVMAP ) || defined ( USE_SKINNING )
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinbase_vertex>
		#include <skinnormal_vertex>
		#include <defaultnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <fog_vertex>
}`,E1=`uniform vec3 diffuse;
uniform float opacity;
#ifndef FLAT_SHADED
	varying vec3 vNormal;
#endif
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		reflectedLight.indirectDiffuse += lightMapTexel.rgb * lightMapIntensity * RECIPROCAL_PI;
	#else
		reflectedLight.indirectDiffuse += vec3( 1.0 );
	#endif
	#include <aomap_fragment>
	reflectedLight.indirectDiffuse *= diffuseColor.rgb;
	vec3 outgoingLight = reflectedLight.indirectDiffuse;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,T1=`#define LAMBERT
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,A1=`#define LAMBERT
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_lambert_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_lambert_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,C1=`#define MATCAP
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <displacementmap_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
	vViewPosition = - mvPosition.xyz;
}`,R1=`#define MATCAP
uniform vec3 diffuse;
uniform float opacity;
uniform sampler2D matcap;
varying vec3 vViewPosition;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	vec3 viewDir = normalize( vViewPosition );
	vec3 x = normalize( vec3( viewDir.z, 0.0, - viewDir.x ) );
	vec3 y = cross( viewDir, x );
	vec2 uv = vec2( dot( x, normal ), dot( y, normal ) ) * 0.495 + 0.5;
	#ifdef USE_MATCAP
		vec4 matcapColor = texture2D( matcap, uv );
	#else
		vec4 matcapColor = vec4( vec3( mix( 0.2, 0.8, uv.y ) ), 1.0 );
	#endif
	vec3 outgoingLight = diffuseColor.rgb * matcapColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,P1=`#define NORMAL
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	vViewPosition = - mvPosition.xyz;
#endif
}`,L1=`#define NORMAL
uniform float opacity;
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <packing>
#include <uv_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( 0.0, 0.0, 0.0, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	gl_FragColor = vec4( packNormalToRGB( normal ), diffuseColor.a );
	#ifdef OPAQUE
		gl_FragColor.a = 1.0;
	#endif
}`,D1=`#define PHONG
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,I1=`#define PHONG
uniform vec3 diffuse;
uniform vec3 emissive;
uniform vec3 specular;
uniform float shininess;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_phong_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_phong_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + reflectedLight.directSpecular + reflectedLight.indirectSpecular + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,U1=`#define STANDARD
varying vec3 vViewPosition;
#ifdef USE_TRANSMISSION
	varying vec3 vWorldPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
#ifdef USE_TRANSMISSION
	vWorldPosition = worldPosition.xyz;
#endif
}`,N1=`#define STANDARD
#ifdef PHYSICAL
	#define IOR
	#define USE_SPECULAR
#endif
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;
#ifdef IOR
	uniform float ior;
#endif
#ifdef USE_SPECULAR
	uniform float specularIntensity;
	uniform vec3 specularColor;
	#ifdef USE_SPECULAR_COLORMAP
		uniform sampler2D specularColorMap;
	#endif
	#ifdef USE_SPECULAR_INTENSITYMAP
		uniform sampler2D specularIntensityMap;
	#endif
#endif
#ifdef USE_CLEARCOAT
	uniform float clearcoat;
	uniform float clearcoatRoughness;
#endif
#ifdef USE_DISPERSION
	uniform float dispersion;
#endif
#ifdef USE_IRIDESCENCE
	uniform float iridescence;
	uniform float iridescenceIOR;
	uniform float iridescenceThicknessMinimum;
	uniform float iridescenceThicknessMaximum;
#endif
#ifdef USE_SHEEN
	uniform vec3 sheenColor;
	uniform float sheenRoughness;
	#ifdef USE_SHEEN_COLORMAP
		uniform sampler2D sheenColorMap;
	#endif
	#ifdef USE_SHEEN_ROUGHNESSMAP
		uniform sampler2D sheenRoughnessMap;
	#endif
#endif
#ifdef USE_ANISOTROPY
	uniform vec2 anisotropyVector;
	#ifdef USE_ANISOTROPYMAP
		uniform sampler2D anisotropyMap;
	#endif
#endif
varying vec3 vViewPosition;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <iridescence_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_physical_pars_fragment>
#include <transmission_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <clearcoat_pars_fragment>
#include <iridescence_pars_fragment>
#include <roughnessmap_pars_fragment>
#include <metalnessmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <roughnessmap_fragment>
	#include <metalnessmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <clearcoat_normal_fragment_begin>
	#include <clearcoat_normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_physical_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 totalDiffuse = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
	vec3 totalSpecular = reflectedLight.directSpecular + reflectedLight.indirectSpecular;
	#include <transmission_fragment>
	vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;
	#ifdef USE_SHEEN
		float sheenEnergyComp = 1.0 - 0.157 * max3( material.sheenColor );
		outgoingLight = outgoingLight * sheenEnergyComp + sheenSpecularDirect + sheenSpecularIndirect;
	#endif
	#ifdef USE_CLEARCOAT
		float dotNVcc = saturate( dot( geometryClearcoatNormal, geometryViewDir ) );
		vec3 Fcc = F_Schlick( material.clearcoatF0, material.clearcoatF90, dotNVcc );
		outgoingLight = outgoingLight * ( 1.0 - material.clearcoat * Fcc ) + ( clearcoatSpecularDirect + clearcoatSpecularIndirect ) * material.clearcoat;
	#endif
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,F1=`#define TOON
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,O1=`#define TOON
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <packing>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <gradientmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_toon_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_toon_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,k1=`uniform float size;
uniform float scale;
#include <common>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
#ifdef USE_POINTS_UV
	varying vec2 vUv;
	uniform mat3 uvTransform;
#endif
void main() {
	#ifdef USE_POINTS_UV
		vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	#endif
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	gl_PointSize = size;
	#ifdef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) gl_PointSize *= ( scale / - mvPosition.z );
	#endif
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <fog_vertex>
}`,B1=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <color_pars_fragment>
#include <map_particle_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_particle_fragment>
	#include <color_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,z1=`#include <common>
#include <batching_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>
void main() {
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,H1=`uniform vec3 color;
uniform float opacity;
#include <common>
#include <packing>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <logdepthbuf_pars_fragment>
#include <shadowmap_pars_fragment>
#include <shadowmask_pars_fragment>
void main() {
	#include <logdepthbuf_fragment>
	gl_FragColor = vec4( color, opacity * ( 1.0 - getShadowMask() ) );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,G1=`uniform float rotation;
uniform vec2 center;
#include <common>
#include <uv_pars_vertex>
#include <fog_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	vec4 mvPosition = modelViewMatrix[ 3 ];
	vec2 scale = vec2( length( modelMatrix[ 0 ].xyz ), length( modelMatrix[ 1 ].xyz ) );
	#ifndef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) scale *= - mvPosition.z;
	#endif
	vec2 alignedPosition = ( position.xy - ( center - vec2( 0.5 ) ) ) * scale;
	vec2 rotatedPosition;
	rotatedPosition.x = cos( rotation ) * alignedPosition.x - sin( rotation ) * alignedPosition.y;
	rotatedPosition.y = sin( rotation ) * alignedPosition.x + cos( rotation ) * alignedPosition.y;
	mvPosition.xy += rotatedPosition;
	gl_Position = projectionMatrix * mvPosition;
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,V1=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,et={alphahash_fragment:hv,alphahash_pars_fragment:fv,alphamap_fragment:dv,alphamap_pars_fragment:pv,alphatest_fragment:mv,alphatest_pars_fragment:gv,aomap_fragment:vv,aomap_pars_fragment:_v,batching_pars_vertex:xv,batching_vertex:yv,begin_vertex:Sv,beginnormal_vertex:Mv,bsdfs:bv,iridescence_fragment:wv,bumpmap_pars_fragment:Ev,clipping_planes_fragment:Tv,clipping_planes_pars_fragment:Av,clipping_planes_pars_vertex:Cv,clipping_planes_vertex:Rv,color_fragment:Pv,color_pars_fragment:Lv,color_pars_vertex:Dv,color_vertex:Iv,common:Uv,cube_uv_reflection_fragment:Nv,defaultnormal_vertex:Fv,displacementmap_pars_vertex:Ov,displacementmap_vertex:kv,emissivemap_fragment:Bv,emissivemap_pars_fragment:zv,colorspace_fragment:Hv,colorspace_pars_fragment:Gv,envmap_fragment:Vv,envmap_common_pars_fragment:Wv,envmap_pars_fragment:Xv,envmap_pars_vertex:qv,envmap_physical_pars_fragment:i_,envmap_vertex:$v,fog_vertex:Yv,fog_pars_vertex:Kv,fog_fragment:jv,fog_pars_fragment:Zv,gradientmap_pars_fragment:Jv,lightmap_pars_fragment:Qv,lights_lambert_fragment:e_,lights_lambert_pars_fragment:t_,lights_pars_begin:n_,lights_toon_fragment:r_,lights_toon_pars_fragment:s_,lights_phong_fragment:o_,lights_phong_pars_fragment:a_,lights_physical_fragment:l_,lights_physical_pars_fragment:c_,lights_fragment_begin:u_,lights_fragment_maps:h_,lights_fragment_end:f_,logdepthbuf_fragment:d_,logdepthbuf_pars_fragment:p_,logdepthbuf_pars_vertex:m_,logdepthbuf_vertex:g_,map_fragment:v_,map_pars_fragment:__,map_particle_fragment:x_,map_particle_pars_fragment:y_,metalnessmap_fragment:S_,metalnessmap_pars_fragment:M_,morphinstance_vertex:b_,morphcolor_vertex:w_,morphnormal_vertex:E_,morphtarget_pars_vertex:T_,morphtarget_vertex:A_,normal_fragment_begin:C_,normal_fragment_maps:R_,normal_pars_fragment:P_,normal_pars_vertex:L_,normal_vertex:D_,normalmap_pars_fragment:I_,clearcoat_normal_fragment_begin:U_,clearcoat_normal_fragment_maps:N_,clearcoat_pars_fragment:F_,iridescence_pars_fragment:O_,opaque_fragment:k_,packing:B_,premultiplied_alpha_fragment:z_,project_vertex:H_,dithering_fragment:G_,dithering_pars_fragment:V_,roughnessmap_fragment:W_,roughnessmap_pars_fragment:X_,shadowmap_pars_fragment:q_,shadowmap_pars_vertex:$_,shadowmap_vertex:Y_,shadowmask_pars_fragment:K_,skinbase_vertex:j_,skinning_pars_vertex:Z_,skinning_vertex:J_,skinnormal_vertex:Q_,specularmap_fragment:e1,specularmap_pars_fragment:t1,tonemapping_fragment:n1,tonemapping_pars_fragment:i1,transmission_fragment:r1,transmission_pars_fragment:s1,uv_pars_fragment:o1,uv_pars_vertex:a1,uv_vertex:l1,worldpos_vertex:c1,background_vert:u1,background_frag:h1,backgroundCube_vert:f1,backgroundCube_frag:d1,cube_vert:p1,cube_frag:m1,depth_vert:g1,depth_frag:v1,distanceRGBA_vert:_1,distanceRGBA_frag:x1,equirect_vert:y1,equirect_frag:S1,linedashed_vert:M1,linedashed_frag:b1,meshbasic_vert:w1,meshbasic_frag:E1,meshlambert_vert:T1,meshlambert_frag:A1,meshmatcap_vert:C1,meshmatcap_frag:R1,meshnormal_vert:P1,meshnormal_frag:L1,meshphong_vert:D1,meshphong_frag:I1,meshphysical_vert:U1,meshphysical_frag:N1,meshtoon_vert:F1,meshtoon_frag:O1,points_vert:k1,points_frag:B1,shadow_vert:z1,shadow_frag:H1,sprite_vert:G1,sprite_frag:V1},Ie={common:{diffuse:{value:new st(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new tt},alphaMap:{value:null},alphaMapTransform:{value:new tt},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new tt}},envmap:{envMap:{value:null},envMapRotation:{value:new tt},flipEnvMap:{value:-1},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new tt}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new tt}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new tt},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new tt},normalScale:{value:new we(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new tt},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new tt}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new tt}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new tt}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new st(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMap:{value:[]},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotShadowMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMap:{value:[]},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null}},points:{diffuse:{value:new st(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new tt},alphaTest:{value:0},uvTransform:{value:new tt}},sprite:{diffuse:{value:new st(16777215)},opacity:{value:1},center:{value:new we(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new tt},alphaMap:{value:null},alphaMapTransform:{value:new tt},alphaTest:{value:0}}},gi={basic:{uniforms:_n([Ie.common,Ie.specularmap,Ie.envmap,Ie.aomap,Ie.lightmap,Ie.fog]),vertexShader:et.meshbasic_vert,fragmentShader:et.meshbasic_frag},lambert:{uniforms:_n([Ie.common,Ie.specularmap,Ie.envmap,Ie.aomap,Ie.lightmap,Ie.emissivemap,Ie.bumpmap,Ie.normalmap,Ie.displacementmap,Ie.fog,Ie.lights,{emissive:{value:new st(0)}}]),vertexShader:et.meshlambert_vert,fragmentShader:et.meshlambert_frag},phong:{uniforms:_n([Ie.common,Ie.specularmap,Ie.envmap,Ie.aomap,Ie.lightmap,Ie.emissivemap,Ie.bumpmap,Ie.normalmap,Ie.displacementmap,Ie.fog,Ie.lights,{emissive:{value:new st(0)},specular:{value:new st(1118481)},shininess:{value:30}}]),vertexShader:et.meshphong_vert,fragmentShader:et.meshphong_frag},standard:{uniforms:_n([Ie.common,Ie.envmap,Ie.aomap,Ie.lightmap,Ie.emissivemap,Ie.bumpmap,Ie.normalmap,Ie.displacementmap,Ie.roughnessmap,Ie.metalnessmap,Ie.fog,Ie.lights,{emissive:{value:new st(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:et.meshphysical_vert,fragmentShader:et.meshphysical_frag},toon:{uniforms:_n([Ie.common,Ie.aomap,Ie.lightmap,Ie.emissivemap,Ie.bumpmap,Ie.normalmap,Ie.displacementmap,Ie.gradientmap,Ie.fog,Ie.lights,{emissive:{value:new st(0)}}]),vertexShader:et.meshtoon_vert,fragmentShader:et.meshtoon_frag},matcap:{uniforms:_n([Ie.common,Ie.bumpmap,Ie.normalmap,Ie.displacementmap,Ie.fog,{matcap:{value:null}}]),vertexShader:et.meshmatcap_vert,fragmentShader:et.meshmatcap_frag},points:{uniforms:_n([Ie.points,Ie.fog]),vertexShader:et.points_vert,fragmentShader:et.points_frag},dashed:{uniforms:_n([Ie.common,Ie.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:et.linedashed_vert,fragmentShader:et.linedashed_frag},depth:{uniforms:_n([Ie.common,Ie.displacementmap]),vertexShader:et.depth_vert,fragmentShader:et.depth_frag},normal:{uniforms:_n([Ie.common,Ie.bumpmap,Ie.normalmap,Ie.displacementmap,{opacity:{value:1}}]),vertexShader:et.meshnormal_vert,fragmentShader:et.meshnormal_frag},sprite:{uniforms:_n([Ie.sprite,Ie.fog]),vertexShader:et.sprite_vert,fragmentShader:et.sprite_frag},background:{uniforms:{uvTransform:{value:new tt},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:et.background_vert,fragmentShader:et.background_frag},backgroundCube:{uniforms:{envMap:{value:null},flipEnvMap:{value:-1},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new tt}},vertexShader:et.backgroundCube_vert,fragmentShader:et.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:et.cube_vert,fragmentShader:et.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:et.equirect_vert,fragmentShader:et.equirect_frag},distanceRGBA:{uniforms:_n([Ie.common,Ie.displacementmap,{referencePosition:{value:new O},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:et.distanceRGBA_vert,fragmentShader:et.distanceRGBA_frag},shadow:{uniforms:_n([Ie.lights,Ie.fog,{color:{value:new st(0)},opacity:{value:1}}]),vertexShader:et.shadow_vert,fragmentShader:et.shadow_frag}};gi.physical={uniforms:_n([gi.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new tt},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new tt},clearcoatNormalScale:{value:new we(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new tt},dispersion:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new tt},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new tt},sheen:{value:0},sheenColor:{value:new st(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new tt},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new tt},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new tt},transmissionSamplerSize:{value:new we},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new tt},attenuationDistance:{value:0},attenuationColor:{value:new st(0)},specularColor:{value:new st(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new tt},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new tt},anisotropyVector:{value:new we},anisotropyMap:{value:null},anisotropyMapTransform:{value:new tt}}]),vertexShader:et.meshphysical_vert,fragmentShader:et.meshphysical_frag};const Na={r:0,b:0,g:0},Dr=new Mi,W1=new It;function X1(n,e,t,i,r,s,o){const a=new st(0);let l=s===!0?0:1,c,u,h=null,f=0,d=null;function v(x){let _=x.isScene===!0?x.background:null;return _&&_.isTexture&&(_=(x.backgroundBlurriness>0?t:e).get(_)),_}function g(x){let _=!1;const y=v(x);y===null?m(a,l):y&&y.isColor&&(m(y,1),_=!0);const C=n.xr.getEnvironmentBlendMode();C==="additive"?i.buffers.color.setClear(0,0,0,1,o):C==="alpha-blend"&&i.buffers.color.setClear(0,0,0,0,o),(n.autoClear||_)&&(i.buffers.depth.setTest(!0),i.buffers.depth.setMask(!0),i.buffers.color.setMask(!0),n.clear(n.autoClearColor,n.autoClearDepth,n.autoClearStencil))}function p(x,_){const y=v(_);y&&(y.isCubeTexture||y.mapping===Gl)?(u===void 0&&(u=new Gt(new fo(1,1,1),new xt({name:"BackgroundCubeMaterial",uniforms:to(gi.backgroundCube.uniforms),vertexShader:gi.backgroundCube.vertexShader,fragmentShader:gi.backgroundCube.fragmentShader,side:Kt,depthTest:!1,depthWrite:!1,fog:!1})),u.geometry.deleteAttribute("normal"),u.geometry.deleteAttribute("uv"),u.onBeforeRender=function(C,M,w){this.matrixWorld.copyPosition(w.matrixWorld)},Object.defineProperty(u.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),r.update(u)),Dr.copy(_.backgroundRotation),Dr.x*=-1,Dr.y*=-1,Dr.z*=-1,y.isCubeTexture&&y.isRenderTargetTexture===!1&&(Dr.y*=-1,Dr.z*=-1),u.material.uniforms.envMap.value=y,u.material.uniforms.flipEnvMap.value=y.isCubeTexture&&y.isRenderTargetTexture===!1?-1:1,u.material.uniforms.backgroundBlurriness.value=_.backgroundBlurriness,u.material.uniforms.backgroundIntensity.value=_.backgroundIntensity,u.material.uniforms.backgroundRotation.value.setFromMatrix4(W1.makeRotationFromEuler(Dr)),u.material.toneMapped=gt.getTransfer(y.colorSpace)!==Pt,(h!==y||f!==y.version||d!==n.toneMapping)&&(u.material.needsUpdate=!0,h=y,f=y.version,d=n.toneMapping),u.layers.enableAll(),x.unshift(u,u.geometry,u.material,0,0,null)):y&&y.isTexture&&(c===void 0&&(c=new Gt(new as(2,2),new xt({name:"BackgroundMaterial",uniforms:to(gi.background.uniforms),vertexShader:gi.background.vertexShader,fragmentShader:gi.background.fragmentShader,side:zi,depthTest:!1,depthWrite:!1,fog:!1})),c.geometry.deleteAttribute("normal"),Object.defineProperty(c.material,"map",{get:function(){return this.uniforms.t2D.value}}),r.update(c)),c.material.uniforms.t2D.value=y,c.material.uniforms.backgroundIntensity.value=_.backgroundIntensity,c.material.toneMapped=gt.getTransfer(y.colorSpace)!==Pt,y.matrixAutoUpdate===!0&&y.updateMatrix(),c.material.uniforms.uvTransform.value.copy(y.matrix),(h!==y||f!==y.version||d!==n.toneMapping)&&(c.material.needsUpdate=!0,h=y,f=y.version,d=n.toneMapping),c.layers.enableAll(),x.unshift(c,c.geometry,c.material,0,0,null))}function m(x,_){x.getRGB(Na,K0(n)),i.buffers.color.setClear(Na.r,Na.g,Na.b,_,o)}return{getClearColor:function(){return a},setClearColor:function(x,_=1){a.set(x),l=_,m(a,l)},getClearAlpha:function(){return l},setClearAlpha:function(x){l=x,m(a,l)},render:g,addToRenderList:p}}function q1(n,e){const t=n.getParameter(n.MAX_VERTEX_ATTRIBS),i={},r=f(null);let s=r,o=!1;function a(S,b,N,R,H){let T=!1;const k=h(R,N,b);s!==k&&(s=k,c(s.object)),T=d(S,R,N,H),T&&v(S,R,N,H),H!==null&&e.update(H,n.ELEMENT_ARRAY_BUFFER),(T||o)&&(o=!1,y(S,b,N,R),H!==null&&n.bindBuffer(n.ELEMENT_ARRAY_BUFFER,e.get(H).buffer))}function l(){return n.createVertexArray()}function c(S){return n.bindVertexArray(S)}function u(S){return n.deleteVertexArray(S)}function h(S,b,N){const R=N.wireframe===!0;let H=i[S.id];H===void 0&&(H={},i[S.id]=H);let T=H[b.id];T===void 0&&(T={},H[b.id]=T);let k=T[R];return k===void 0&&(k=f(l()),T[R]=k),k}function f(S){const b=[],N=[],R=[];for(let H=0;H<t;H++)b[H]=0,N[H]=0,R[H]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:b,enabledAttributes:N,attributeDivisors:R,object:S,attributes:{},index:null}}function d(S,b,N,R){const H=s.attributes,T=b.attributes;let k=0;const Z=N.getAttributes();for(const K in Z)if(Z[K].location>=0){const ce=H[K];let W=T[K];if(W===void 0&&(K==="instanceMatrix"&&S.instanceMatrix&&(W=S.instanceMatrix),K==="instanceColor"&&S.instanceColor&&(W=S.instanceColor)),ce===void 0||ce.attribute!==W||W&&ce.data!==W.data)return!0;k++}return s.attributesNum!==k||s.index!==R}function v(S,b,N,R){const H={},T=b.attributes;let k=0;const Z=N.getAttributes();for(const K in Z)if(Z[K].location>=0){let ce=T[K];ce===void 0&&(K==="instanceMatrix"&&S.instanceMatrix&&(ce=S.instanceMatrix),K==="instanceColor"&&S.instanceColor&&(ce=S.instanceColor));const W={};W.attribute=ce,ce&&ce.data&&(W.data=ce.data),H[K]=W,k++}s.attributes=H,s.attributesNum=k,s.index=R}function g(){const S=s.newAttributes;for(let b=0,N=S.length;b<N;b++)S[b]=0}function p(S){m(S,0)}function m(S,b){const N=s.newAttributes,R=s.enabledAttributes,H=s.attributeDivisors;N[S]=1,R[S]===0&&(n.enableVertexAttribArray(S),R[S]=1),H[S]!==b&&(n.vertexAttribDivisor(S,b),H[S]=b)}function x(){const S=s.newAttributes,b=s.enabledAttributes;for(let N=0,R=b.length;N<R;N++)b[N]!==S[N]&&(n.disableVertexAttribArray(N),b[N]=0)}function _(S,b,N,R,H,T,k){k===!0?n.vertexAttribIPointer(S,b,N,H,T):n.vertexAttribPointer(S,b,N,R,H,T)}function y(S,b,N,R){g();const H=R.attributes,T=N.getAttributes(),k=b.defaultAttributeValues;for(const Z in T){const K=T[Z];if(K.location>=0){let pe=H[Z];if(pe===void 0&&(Z==="instanceMatrix"&&S.instanceMatrix&&(pe=S.instanceMatrix),Z==="instanceColor"&&S.instanceColor&&(pe=S.instanceColor)),pe!==void 0){const ce=pe.normalized,W=pe.itemSize,re=e.get(pe);if(re===void 0)continue;const Ae=re.buffer,ee=re.type,F=re.bytesPerElement,xe=ee===n.INT||ee===n.UNSIGNED_INT||pe.gpuType===Ah;if(pe.isInterleavedBufferAttribute){const G=pe.data,he=G.stride,me=pe.offset;if(G.isInstancedInterleavedBuffer){for(let fe=0;fe<K.locationSize;fe++)m(K.location+fe,G.meshPerAttribute);S.isInstancedMesh!==!0&&R._maxInstanceCount===void 0&&(R._maxInstanceCount=G.meshPerAttribute*G.count)}else for(let fe=0;fe<K.locationSize;fe++)p(K.location+fe);n.bindBuffer(n.ARRAY_BUFFER,Ae);for(let fe=0;fe<K.locationSize;fe++)_(K.location+fe,W/K.locationSize,ee,ce,he*F,(me+W/K.locationSize*fe)*F,xe)}else{if(pe.isInstancedBufferAttribute){for(let G=0;G<K.locationSize;G++)m(K.location+G,pe.meshPerAttribute);S.isInstancedMesh!==!0&&R._maxInstanceCount===void 0&&(R._maxInstanceCount=pe.meshPerAttribute*pe.count)}else for(let G=0;G<K.locationSize;G++)p(K.location+G);n.bindBuffer(n.ARRAY_BUFFER,Ae);for(let G=0;G<K.locationSize;G++)_(K.location+G,W/K.locationSize,ee,ce,W*F,W/K.locationSize*G*F,xe)}}else if(k!==void 0){const ce=k[Z];if(ce!==void 0)switch(ce.length){case 2:n.vertexAttrib2fv(K.location,ce);break;case 3:n.vertexAttrib3fv(K.location,ce);break;case 4:n.vertexAttrib4fv(K.location,ce);break;default:n.vertexAttrib1fv(K.location,ce)}}}}x()}function C(){P();for(const S in i){const b=i[S];for(const N in b){const R=b[N];for(const H in R)u(R[H].object),delete R[H];delete b[N]}delete i[S]}}function M(S){if(i[S.id]===void 0)return;const b=i[S.id];for(const N in b){const R=b[N];for(const H in R)u(R[H].object),delete R[H];delete b[N]}delete i[S.id]}function w(S){for(const b in i){const N=i[b];if(N[S.id]===void 0)continue;const R=N[S.id];for(const H in R)u(R[H].object),delete R[H];delete N[S.id]}}function P(){I(),o=!0,s!==r&&(s=r,c(s.object))}function I(){r.geometry=null,r.program=null,r.wireframe=!1}return{setup:a,reset:P,resetDefaultState:I,dispose:C,releaseStatesOfGeometry:M,releaseStatesOfProgram:w,initAttributes:g,enableAttribute:p,disableUnusedAttributes:x}}function $1(n,e,t){let i;function r(c){i=c}function s(c,u){n.drawArrays(i,c,u),t.update(u,i,1)}function o(c,u,h){h!==0&&(n.drawArraysInstanced(i,c,u,h),t.update(u,i,h))}function a(c,u,h){if(h===0)return;e.get("WEBGL_multi_draw").multiDrawArraysWEBGL(i,c,0,u,0,h);let d=0;for(let v=0;v<h;v++)d+=u[v];t.update(d,i,1)}function l(c,u,h,f){if(h===0)return;const d=e.get("WEBGL_multi_draw");if(d===null)for(let v=0;v<c.length;v++)o(c[v],u[v],f[v]);else{d.multiDrawArraysInstancedWEBGL(i,c,0,u,0,f,0,h);let v=0;for(let g=0;g<h;g++)v+=u[g];for(let g=0;g<f.length;g++)t.update(v,i,f[g])}}this.setMode=r,this.render=s,this.renderInstances=o,this.renderMultiDraw=a,this.renderMultiDrawInstances=l}function Y1(n,e,t,i){let r;function s(){if(r!==void 0)return r;if(e.has("EXT_texture_filter_anisotropic")===!0){const w=e.get("EXT_texture_filter_anisotropic");r=n.getParameter(w.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else r=0;return r}function o(w){return!(w!==Hn&&i.convert(w)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_FORMAT))}function a(w){const P=w===ho&&(e.has("EXT_color_buffer_half_float")||e.has("EXT_color_buffer_float"));return!(w!==on&&i.convert(w)!==n.getParameter(n.IMPLEMENTATION_COLOR_READ_TYPE)&&w!==_i&&!P)}function l(w){if(w==="highp"){if(n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.HIGH_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.HIGH_FLOAT).precision>0)return"highp";w="mediump"}return w==="mediump"&&n.getShaderPrecisionFormat(n.VERTEX_SHADER,n.MEDIUM_FLOAT).precision>0&&n.getShaderPrecisionFormat(n.FRAGMENT_SHADER,n.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let c=t.precision!==void 0?t.precision:"highp";const u=l(c);u!==c&&(console.warn("THREE.WebGLRenderer:",c,"not supported, using",u,"instead."),c=u);const h=t.logarithmicDepthBuffer===!0,f=t.reverseDepthBuffer===!0&&e.has("EXT_clip_control");if(f===!0){const w=e.get("EXT_clip_control");w.clipControlEXT(w.LOWER_LEFT_EXT,w.ZERO_TO_ONE_EXT)}const d=n.getParameter(n.MAX_TEXTURE_IMAGE_UNITS),v=n.getParameter(n.MAX_VERTEX_TEXTURE_IMAGE_UNITS),g=n.getParameter(n.MAX_TEXTURE_SIZE),p=n.getParameter(n.MAX_CUBE_MAP_TEXTURE_SIZE),m=n.getParameter(n.MAX_VERTEX_ATTRIBS),x=n.getParameter(n.MAX_VERTEX_UNIFORM_VECTORS),_=n.getParameter(n.MAX_VARYING_VECTORS),y=n.getParameter(n.MAX_FRAGMENT_UNIFORM_VECTORS),C=v>0,M=n.getParameter(n.MAX_SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:s,getMaxPrecision:l,textureFormatReadable:o,textureTypeReadable:a,precision:c,logarithmicDepthBuffer:h,reverseDepthBuffer:f,maxTextures:d,maxVertexTextures:v,maxTextureSize:g,maxCubemapSize:p,maxAttributes:m,maxVertexUniforms:x,maxVaryings:_,maxFragmentUniforms:y,vertexTextures:C,maxSamples:M}}function K1(n){const e=this;let t=null,i=0,r=!1,s=!1;const o=new Or,a=new tt,l={value:null,needsUpdate:!1};this.uniform=l,this.numPlanes=0,this.numIntersection=0,this.init=function(h,f){const d=h.length!==0||f||i!==0||r;return r=f,i=h.length,d},this.beginShadows=function(){s=!0,u(null)},this.endShadows=function(){s=!1},this.setGlobalState=function(h,f){t=u(h,f,0)},this.setState=function(h,f,d){const v=h.clippingPlanes,g=h.clipIntersection,p=h.clipShadows,m=n.get(h);if(!r||v===null||v.length===0||s&&!p)s?u(null):c();else{const x=s?0:i,_=x*4;let y=m.clippingState||null;l.value=y,y=u(v,f,_,d);for(let C=0;C!==_;++C)y[C]=t[C];m.clippingState=y,this.numIntersection=g?this.numPlanes:0,this.numPlanes+=x}};function c(){l.value!==t&&(l.value=t,l.needsUpdate=i>0),e.numPlanes=i,e.numIntersection=0}function u(h,f,d,v){const g=h!==null?h.length:0;let p=null;if(g!==0){if(p=l.value,v!==!0||p===null){const m=d+g*4,x=f.matrixWorldInverse;a.getNormalMatrix(x),(p===null||p.length<m)&&(p=new Float32Array(m));for(let _=0,y=d;_!==g;++_,y+=4)o.copy(h[_]).applyMatrix4(x,a),o.normal.toArray(p,y),p[y+3]=o.constant}l.value=p,l.needsUpdate=!0}return e.numPlanes=g,e.numIntersection=0,p}}function j1(n){let e=new WeakMap;function t(o,a){return a===Su?o.mapping=Qs:a===Mu&&(o.mapping=eo),o}function i(o){if(o&&o.isTexture){const a=o.mapping;if(a===Su||a===Mu)if(e.has(o)){const l=e.get(o).texture;return t(l,o.mapping)}else{const l=o.image;if(l&&l.height>0){const c=new av(l.height);return c.fromEquirectangularTexture(n,o),e.set(o,c),o.addEventListener("dispose",r),t(c.texture,o.mapping)}else return null}}return o}function r(o){const a=o.target;a.removeEventListener("dispose",r);const l=e.get(a);l!==void 0&&(e.delete(a),l.dispose())}function s(){e=new WeakMap}return{get:i,dispose:s}}class Z1 extends Nh{constructor(e=-1,t=1,i=1,r=-1,s=.1,o=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=e,this.right=t,this.top=i,this.bottom=r,this.near=s,this.far=o,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.left=e.left,this.right=e.right,this.top=e.top,this.bottom=e.bottom,this.near=e.near,this.far=e.far,this.zoom=e.zoom,this.view=e.view===null?null:Object.assign({},e.view),this}setViewOffset(e,t,i,r,s,o){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=i,this.view.offsetY=r,this.view.width=s,this.view.height=o,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){const e=(this.right-this.left)/(2*this.zoom),t=(this.top-this.bottom)/(2*this.zoom),i=(this.right+this.left)/2,r=(this.top+this.bottom)/2;let s=i-e,o=i+e,a=r+t,l=r-t;if(this.view!==null&&this.view.enabled){const c=(this.right-this.left)/this.view.fullWidth/this.zoom,u=(this.top-this.bottom)/this.view.fullHeight/this.zoom;s+=c*this.view.offsetX,o=s+c*this.view.width,a-=u*this.view.offsetY,l=a-u*this.view.height}this.projectionMatrix.makeOrthographic(s,o,a,l,this.near,this.far,this.coordinateSystem),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){const t=super.toJSON(e);return t.object.zoom=this.zoom,t.object.left=this.left,t.object.right=this.right,t.object.top=this.top,t.object.bottom=this.bottom,t.object.near=this.near,t.object.far=this.far,this.view!==null&&(t.object.view=Object.assign({},this.view)),t}}const Os=4,$f=[.125,.215,.35,.446,.526,.582],Hr=20,Ec=new Z1,Yf=new st;let Tc=null,Ac=0,Cc=0,Rc=!1;const kr=(1+Math.sqrt(5))/2,Es=1/kr,Kf=[new O(-kr,Es,0),new O(kr,Es,0),new O(-Es,0,kr),new O(Es,0,kr),new O(0,kr,-Es),new O(0,kr,Es),new O(-1,1,-1),new O(1,1,-1),new O(-1,1,1),new O(1,1,1)];class jf{constructor(e){this._renderer=e,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._lodPlanes=[],this._sizeLods=[],this._sigmas=[],this._blurMaterial=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._compileMaterial(this._blurMaterial)}fromScene(e,t=0,i=.1,r=100){Tc=this._renderer.getRenderTarget(),Ac=this._renderer.getActiveCubeFace(),Cc=this._renderer.getActiveMipmapLevel(),Rc=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(256);const s=this._allocateTargets();return s.depthBuffer=!0,this._sceneToCubeUV(e,i,r,s),t>0&&this._blur(s,0,0,t),this._applyPMREM(s),this._cleanup(s),s}fromEquirectangular(e,t=null){return this._fromTexture(e,t)}fromCubemap(e,t=null){return this._fromTexture(e,t)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=Qf(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=Jf(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose()}_setSize(e){this._lodMax=Math.floor(Math.log2(e)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let e=0;e<this._lodPlanes.length;e++)this._lodPlanes[e].dispose()}_cleanup(e){this._renderer.setRenderTarget(Tc,Ac,Cc),this._renderer.xr.enabled=Rc,e.scissorTest=!1,Fa(e,0,0,e.width,e.height)}_fromTexture(e,t){e.mapping===Qs||e.mapping===eo?this._setSize(e.image.length===0?16:e.image[0].width||e.image[0].image.width):this._setSize(e.image.width/4),Tc=this._renderer.getRenderTarget(),Ac=this._renderer.getActiveCubeFace(),Cc=this._renderer.getActiveMipmapLevel(),Rc=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;const i=t||this._allocateTargets();return this._textureToCubeUV(e,i),this._applyPMREM(i),this._cleanup(i),i}_allocateTargets(){const e=3*Math.max(this._cubeSize,112),t=4*this._cubeSize,i={magFilter:hn,minFilter:hn,generateMipmaps:!1,type:ho,format:Hn,colorSpace:wi,depthBuffer:!1},r=Zf(e,t,i);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==e||this._pingPongRenderTarget.height!==t){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=Zf(e,t,i);const{_lodMax:s}=this;({sizeLods:this._sizeLods,lodPlanes:this._lodPlanes,sigmas:this._sigmas}=J1(s)),this._blurMaterial=Q1(s,e,t)}return r}_compileMaterial(e){const t=new Gt(this._lodPlanes[0],e);this._renderer.compile(t,Ec)}_sceneToCubeUV(e,t,i,r){const a=new kn(90,1,t,i),l=[1,-1,1,1,1,1],c=[1,1,1,-1,-1,-1],u=this._renderer,h=u.autoClear,f=u.toneMapping;u.getClearColor(Yf),u.toneMapping=ki,u.autoClear=!1;const d=new Y0({name:"PMREM.Background",side:Kt,depthWrite:!1,depthTest:!1}),v=new Gt(new fo,d);let g=!1;const p=e.background;p?p.isColor&&(d.color.copy(p),e.background=null,g=!0):(d.color.copy(Yf),g=!0);for(let m=0;m<6;m++){const x=m%3;x===0?(a.up.set(0,l[m],0),a.lookAt(c[m],0,0)):x===1?(a.up.set(0,0,l[m]),a.lookAt(0,c[m],0)):(a.up.set(0,l[m],0),a.lookAt(0,0,c[m]));const _=this._cubeSize;Fa(r,x*_,m>2?_:0,_,_),u.setRenderTarget(r),g&&u.render(v,a),u.render(e,a)}v.geometry.dispose(),v.material.dispose(),u.toneMapping=f,u.autoClear=h,e.background=p}_textureToCubeUV(e,t){const i=this._renderer,r=e.mapping===Qs||e.mapping===eo;r?(this._cubemapMaterial===null&&(this._cubemapMaterial=Qf()),this._cubemapMaterial.uniforms.flipEnvMap.value=e.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=Jf());const s=r?this._cubemapMaterial:this._equirectMaterial,o=new Gt(this._lodPlanes[0],s),a=s.uniforms;a.envMap.value=e;const l=this._cubeSize;Fa(t,0,0,3*l,2*l),i.setRenderTarget(t),i.render(o,Ec)}_applyPMREM(e){const t=this._renderer,i=t.autoClear;t.autoClear=!1;const r=this._lodPlanes.length;for(let s=1;s<r;s++){const o=Math.sqrt(this._sigmas[s]*this._sigmas[s]-this._sigmas[s-1]*this._sigmas[s-1]),a=Kf[(r-s-1)%Kf.length];this._blur(e,s-1,s,o,a)}t.autoClear=i}_blur(e,t,i,r,s){const o=this._pingPongRenderTarget;this._halfBlur(e,o,t,i,r,"latitudinal",s),this._halfBlur(o,e,i,i,r,"longitudinal",s)}_halfBlur(e,t,i,r,s,o,a){const l=this._renderer,c=this._blurMaterial;o!=="latitudinal"&&o!=="longitudinal"&&console.error("blur direction must be either latitudinal or longitudinal!");const u=3,h=new Gt(this._lodPlanes[r],c),f=c.uniforms,d=this._sizeLods[i]-1,v=isFinite(s)?Math.PI/(2*d):2*Math.PI/(2*Hr-1),g=s/v,p=isFinite(s)?1+Math.floor(u*g):Hr;p>Hr&&console.warn(`sigmaRadians, ${s}, is too large and will clip, as it requested ${p} samples when the maximum is set to ${Hr}`);const m=[];let x=0;for(let w=0;w<Hr;++w){const P=w/g,I=Math.exp(-P*P/2);m.push(I),w===0?x+=I:w<p&&(x+=2*I)}for(let w=0;w<m.length;w++)m[w]=m[w]/x;f.envMap.value=e.texture,f.samples.value=p,f.weights.value=m,f.latitudinal.value=o==="latitudinal",a&&(f.poleAxis.value=a);const{_lodMax:_}=this;f.dTheta.value=v,f.mipInt.value=_-i;const y=this._sizeLods[r],C=3*y*(r>_-Os?r-_+Os:0),M=4*(this._cubeSize-y);Fa(t,C,M,3*y,2*y),l.setRenderTarget(t),l.render(h,Ec)}}function J1(n){const e=[],t=[],i=[];let r=n;const s=n-Os+1+$f.length;for(let o=0;o<s;o++){const a=Math.pow(2,r);t.push(a);let l=1/a;o>n-Os?l=$f[o-n+Os-1]:o===0&&(l=0),i.push(l);const c=1/(a-2),u=-c,h=1+c,f=[u,u,h,u,h,h,u,u,h,h,u,h],d=6,v=6,g=3,p=2,m=1,x=new Float32Array(g*v*d),_=new Float32Array(p*v*d),y=new Float32Array(m*v*d);for(let M=0;M<d;M++){const w=M%3*2/3-1,P=M>2?0:-1,I=[w,P,0,w+2/3,P,0,w+2/3,P+1,0,w,P,0,w+2/3,P+1,0,w,P+1,0];x.set(I,g*v*M),_.set(f,p*v*M);const S=[M,M,M,M,M,M];y.set(S,m*v*M)}const C=new Et;C.setAttribute("position",new kt(x,g)),C.setAttribute("uv",new kt(_,p)),C.setAttribute("faceIndex",new kt(y,m)),e.push(C),r>Os&&r--}return{lodPlanes:e,sizeLods:t,sigmas:i}}function Zf(n,e,t){const i=new Sn(n,e,t);return i.texture.mapping=Gl,i.texture.name="PMREM.cubeUv",i.scissorTest=!0,i}function Fa(n,e,t,i,r){n.viewport.set(e,t,i,r),n.scissor.set(e,t,i,r)}function Q1(n,e,t){const i=new Float32Array(Hr),r=new O(0,1,0);return new xt({name:"SphericalGaussianBlur",defines:{n:Hr,CUBEUV_TEXEL_WIDTH:1/e,CUBEUV_TEXEL_HEIGHT:1/t,CUBEUV_MAX_MIP:`${n}.0`},uniforms:{envMap:{value:null},samples:{value:1},weights:{value:i},latitudinal:{value:!1},dTheta:{value:0},mipInt:{value:0},poleAxis:{value:r}},vertexShader:Fh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;
			uniform int samples;
			uniform float weights[ n ];
			uniform bool latitudinal;
			uniform float dTheta;
			uniform float mipInt;
			uniform vec3 poleAxis;

			#define ENVMAP_TYPE_CUBE_UV
			#include <cube_uv_reflection_fragment>

			vec3 getSample( float theta, vec3 axis ) {

				float cosTheta = cos( theta );
				// Rodrigues' axis-angle rotation
				vec3 sampleDirection = vOutputDirection * cosTheta
					+ cross( axis, vOutputDirection ) * sin( theta )
					+ axis * dot( axis, vOutputDirection ) * ( 1.0 - cosTheta );

				return bilinearCubeUV( envMap, sampleDirection, mipInt );

			}

			void main() {

				vec3 axis = latitudinal ? poleAxis : cross( poleAxis, vOutputDirection );

				if ( all( equal( axis, vec3( 0.0 ) ) ) ) {

					axis = vec3( vOutputDirection.z, 0.0, - vOutputDirection.x );

				}

				axis = normalize( axis );

				gl_FragColor = vec4( 0.0, 0.0, 0.0, 1.0 );
				gl_FragColor.rgb += weights[ 0 ] * getSample( 0.0, axis );

				for ( int i = 1; i < n; i++ ) {

					if ( i >= samples ) {

						break;

					}

					float theta = dTheta * float( i );
					gl_FragColor.rgb += weights[ i ] * getSample( -1.0 * theta, axis );
					gl_FragColor.rgb += weights[ i ] * getSample( theta, axis );

				}

			}
		`,blending:An,depthTest:!1,depthWrite:!1})}function Jf(){return new xt({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Fh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;

			#include <common>

			void main() {

				vec3 outputDirection = normalize( vOutputDirection );
				vec2 uv = equirectUv( outputDirection );

				gl_FragColor = vec4( texture2D ( envMap, uv ).rgb, 1.0 );

			}
		`,blending:An,depthTest:!1,depthWrite:!1})}function Qf(){return new xt({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Fh(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:An,depthTest:!1,depthWrite:!1})}function Fh(){return`

		precision mediump float;
		precision mediump int;

		attribute float faceIndex;

		varying vec3 vOutputDirection;

		// RH coordinate system; PMREM face-indexing convention
		vec3 getDirection( vec2 uv, float face ) {

			uv = 2.0 * uv - 1.0;

			vec3 direction = vec3( uv, 1.0 );

			if ( face == 0.0 ) {

				direction = direction.zyx; // ( 1, v, u ) pos x

			} else if ( face == 1.0 ) {

				direction = direction.xzy;
				direction.xz *= -1.0; // ( -u, 1, -v ) pos y

			} else if ( face == 2.0 ) {

				direction.x *= -1.0; // ( -u, v, 1 ) pos z

			} else if ( face == 3.0 ) {

				direction = direction.zyx;
				direction.xz *= -1.0; // ( -1, v, -u ) neg x

			} else if ( face == 4.0 ) {

				direction = direction.xzy;
				direction.xy *= -1.0; // ( -u, -1, v ) neg y

			} else if ( face == 5.0 ) {

				direction.z *= -1.0; // ( u, v, -1 ) neg z

			}

			return direction;

		}

		void main() {

			vOutputDirection = getDirection( uv, faceIndex );
			gl_Position = vec4( position, 1.0 );

		}
	`}function ex(n){let e=new WeakMap,t=null;function i(a){if(a&&a.isTexture){const l=a.mapping,c=l===Su||l===Mu,u=l===Qs||l===eo;if(c||u){let h=e.get(a);const f=h!==void 0?h.texture.pmremVersion:0;if(a.isRenderTargetTexture&&a.pmremVersion!==f)return t===null&&(t=new jf(n)),h=c?t.fromEquirectangular(a,h):t.fromCubemap(a,h),h.texture.pmremVersion=a.pmremVersion,e.set(a,h),h.texture;if(h!==void 0)return h.texture;{const d=a.image;return c&&d&&d.height>0||u&&d&&r(d)?(t===null&&(t=new jf(n)),h=c?t.fromEquirectangular(a):t.fromCubemap(a),h.texture.pmremVersion=a.pmremVersion,e.set(a,h),a.addEventListener("dispose",s),h.texture):null}}}return a}function r(a){let l=0;const c=6;for(let u=0;u<c;u++)a[u]!==void 0&&l++;return l===c}function s(a){const l=a.target;l.removeEventListener("dispose",s);const c=e.get(l);c!==void 0&&(e.delete(l),c.dispose())}function o(){e=new WeakMap,t!==null&&(t.dispose(),t=null)}return{get:i,dispose:o}}function tx(n){const e={};function t(i){if(e[i]!==void 0)return e[i];let r;switch(i){case"WEBGL_depth_texture":r=n.getExtension("WEBGL_depth_texture")||n.getExtension("MOZ_WEBGL_depth_texture")||n.getExtension("WEBKIT_WEBGL_depth_texture");break;case"EXT_texture_filter_anisotropic":r=n.getExtension("EXT_texture_filter_anisotropic")||n.getExtension("MOZ_EXT_texture_filter_anisotropic")||n.getExtension("WEBKIT_EXT_texture_filter_anisotropic");break;case"WEBGL_compressed_texture_s3tc":r=n.getExtension("WEBGL_compressed_texture_s3tc")||n.getExtension("MOZ_WEBGL_compressed_texture_s3tc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_s3tc");break;case"WEBGL_compressed_texture_pvrtc":r=n.getExtension("WEBGL_compressed_texture_pvrtc")||n.getExtension("WEBKIT_WEBGL_compressed_texture_pvrtc");break;default:r=n.getExtension(i)}return e[i]=r,r}return{has:function(i){return t(i)!==null},init:function(){t("EXT_color_buffer_float"),t("WEBGL_clip_cull_distance"),t("OES_texture_float_linear"),t("EXT_color_buffer_half_float"),t("WEBGL_multisampled_render_to_texture"),t("WEBGL_render_shared_exponent")},get:function(i){const r=t(i);return r===null&&ul("THREE.WebGLRenderer: "+i+" extension not supported."),r}}}function nx(n,e,t,i){const r={},s=new WeakMap;function o(h){const f=h.target;f.index!==null&&e.remove(f.index);for(const v in f.attributes)e.remove(f.attributes[v]);for(const v in f.morphAttributes){const g=f.morphAttributes[v];for(let p=0,m=g.length;p<m;p++)e.remove(g[p])}f.removeEventListener("dispose",o),delete r[f.id];const d=s.get(f);d&&(e.remove(d),s.delete(f)),i.releaseStatesOfGeometry(f),f.isInstancedBufferGeometry===!0&&delete f._maxInstanceCount,t.memory.geometries--}function a(h,f){return r[f.id]===!0||(f.addEventListener("dispose",o),r[f.id]=!0,t.memory.geometries++),f}function l(h){const f=h.attributes;for(const v in f)e.update(f[v],n.ARRAY_BUFFER);const d=h.morphAttributes;for(const v in d){const g=d[v];for(let p=0,m=g.length;p<m;p++)e.update(g[p],n.ARRAY_BUFFER)}}function c(h){const f=[],d=h.index,v=h.attributes.position;let g=0;if(d!==null){const x=d.array;g=d.version;for(let _=0,y=x.length;_<y;_+=3){const C=x[_+0],M=x[_+1],w=x[_+2];f.push(C,M,M,w,w,C)}}else if(v!==void 0){const x=v.array;g=v.version;for(let _=0,y=x.length/3-1;_<y;_+=3){const C=_+0,M=_+1,w=_+2;f.push(C,M,M,w,w,C)}}else return;const p=new(V0(f)?ql:Xl)(f,1);p.version=g;const m=s.get(h);m&&e.remove(m),s.set(h,p)}function u(h){const f=s.get(h);if(f){const d=h.index;d!==null&&f.version<d.version&&c(h)}else c(h);return s.get(h)}return{get:a,update:l,getWireframeAttribute:u}}function ix(n,e,t){let i;function r(f){i=f}let s,o;function a(f){s=f.type,o=f.bytesPerElement}function l(f,d){n.drawElements(i,d,s,f*o),t.update(d,i,1)}function c(f,d,v){v!==0&&(n.drawElementsInstanced(i,d,s,f*o,v),t.update(d,i,v))}function u(f,d,v){if(v===0)return;e.get("WEBGL_multi_draw").multiDrawElementsWEBGL(i,d,0,s,f,0,v);let p=0;for(let m=0;m<v;m++)p+=d[m];t.update(p,i,1)}function h(f,d,v,g){if(v===0)return;const p=e.get("WEBGL_multi_draw");if(p===null)for(let m=0;m<f.length;m++)c(f[m]/o,d[m],g[m]);else{p.multiDrawElementsInstancedWEBGL(i,d,0,s,f,0,g,0,v);let m=0;for(let x=0;x<v;x++)m+=d[x];for(let x=0;x<g.length;x++)t.update(m,i,g[x])}}this.setMode=r,this.setIndex=a,this.render=l,this.renderInstances=c,this.renderMultiDraw=u,this.renderMultiDrawInstances=h}function rx(n){const e={geometries:0,textures:0},t={frame:0,calls:0,triangles:0,points:0,lines:0};function i(s,o,a){switch(t.calls++,o){case n.TRIANGLES:t.triangles+=a*(s/3);break;case n.LINES:t.lines+=a*(s/2);break;case n.LINE_STRIP:t.lines+=a*(s-1);break;case n.LINE_LOOP:t.lines+=a*s;break;case n.POINTS:t.points+=a*s;break;default:console.error("THREE.WebGLInfo: Unknown draw mode:",o);break}}function r(){t.calls=0,t.triangles=0,t.points=0,t.lines=0}return{memory:e,render:t,programs:null,autoReset:!0,reset:r,update:i}}function sx(n,e,t){const i=new WeakMap,r=new Ct;function s(o,a,l){const c=o.morphTargetInfluences,u=a.morphAttributes.position||a.morphAttributes.normal||a.morphAttributes.color,h=u!==void 0?u.length:0;let f=i.get(a);if(f===void 0||f.count!==h){let S=function(){P.dispose(),i.delete(a),a.removeEventListener("dispose",S)};var d=S;f!==void 0&&f.texture.dispose();const v=a.morphAttributes.position!==void 0,g=a.morphAttributes.normal!==void 0,p=a.morphAttributes.color!==void 0,m=a.morphAttributes.position||[],x=a.morphAttributes.normal||[],_=a.morphAttributes.color||[];let y=0;v===!0&&(y=1),g===!0&&(y=2),p===!0&&(y=3);let C=a.attributes.position.count*y,M=1;C>e.maxTextureSize&&(M=Math.ceil(C/e.maxTextureSize),C=e.maxTextureSize);const w=new Float32Array(C*M*4*h),P=new El(w,C,M,h);P.type=_i,P.needsUpdate=!0;const I=y*4;for(let b=0;b<h;b++){const N=m[b],R=x[b],H=_[b],T=C*M*4*b;for(let k=0;k<N.count;k++){const Z=k*I;v===!0&&(r.fromBufferAttribute(N,k),w[T+Z+0]=r.x,w[T+Z+1]=r.y,w[T+Z+2]=r.z,w[T+Z+3]=0),g===!0&&(r.fromBufferAttribute(R,k),w[T+Z+4]=r.x,w[T+Z+5]=r.y,w[T+Z+6]=r.z,w[T+Z+7]=0),p===!0&&(r.fromBufferAttribute(H,k),w[T+Z+8]=r.x,w[T+Z+9]=r.y,w[T+Z+10]=r.z,w[T+Z+11]=H.itemSize===4?r.w:1)}}f={count:h,texture:P,size:new we(C,M)},i.set(a,f),a.addEventListener("dispose",S)}if(o.isInstancedMesh===!0&&o.morphTexture!==null)l.getUniforms().setValue(n,"morphTexture",o.morphTexture,t);else{let v=0;for(let p=0;p<c.length;p++)v+=c[p];const g=a.morphTargetsRelative?1:1-v;l.getUniforms().setValue(n,"morphTargetBaseInfluence",g),l.getUniforms().setValue(n,"morphTargetInfluences",c)}l.getUniforms().setValue(n,"morphTargetsTexture",f.texture,t),l.getUniforms().setValue(n,"morphTargetsTextureSize",f.size)}return{update:s}}function ox(n,e,t,i){let r=new WeakMap;function s(l){const c=i.render.frame,u=l.geometry,h=e.get(l,u);if(r.get(h)!==c&&(e.update(h),r.set(h,c)),l.isInstancedMesh&&(l.hasEventListener("dispose",a)===!1&&l.addEventListener("dispose",a),r.get(l)!==c&&(t.update(l.instanceMatrix,n.ARRAY_BUFFER),l.instanceColor!==null&&t.update(l.instanceColor,n.ARRAY_BUFFER),r.set(l,c))),l.isSkinnedMesh){const f=l.skeleton;r.get(f)!==c&&(f.update(),r.set(f,c))}return h}function o(){r=new WeakMap}function a(l){const c=l.target;c.removeEventListener("dispose",a),t.remove(c.instanceMatrix),c.instanceColor!==null&&t.remove(c.instanceColor)}return{update:s,dispose:o}}class Oh extends sn{constructor(e,t,i,r,s,o,a,l,c,u=Xs){if(u!==Xs&&u!==Qr)throw new Error("DepthTexture format must be either THREE.DepthFormat or THREE.DepthStencilFormat");i===void 0&&u===Xs&&(i=xr),i===void 0&&u===Qr&&(i=Jr),super(null,r,s,o,a,l,u,i,c),this.isDepthTexture=!0,this.image={width:e,height:t},this.magFilter=a!==void 0?a:dn,this.minFilter=l!==void 0?l:dn,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(e){return super.copy(e),this.compareFunction=e.compareFunction,this}toJSON(e){const t=super.toJSON(e);return this.compareFunction!==null&&(t.compareFunction=this.compareFunction),t}}const Q0=new sn,ed=new Oh(1,1),ep=new El,tp=new Xg,np=new j0,td=[],nd=[],id=new Float32Array(16),rd=new Float32Array(9),sd=new Float32Array(4);function po(n,e,t){const i=n[0];if(i<=0||i>0)return n;const r=e*t;let s=td[r];if(s===void 0&&(s=new Float32Array(r),td[r]=s),e!==0){i.toArray(s,0);for(let o=1,a=0;o!==e;++o)a+=t,n[o].toArray(s,a)}return s}function jt(n,e){if(n.length!==e.length)return!1;for(let t=0,i=n.length;t<i;t++)if(n[t]!==e[t])return!1;return!0}function Zt(n,e){for(let t=0,i=e.length;t<i;t++)n[t]=e[t]}function $l(n,e){let t=nd[e];t===void 0&&(t=new Int32Array(e),nd[e]=t);for(let i=0;i!==e;++i)t[i]=n.allocateTextureUnit();return t}function ax(n,e){const t=this.cache;t[0]!==e&&(n.uniform1f(this.addr,e),t[0]=e)}function lx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2f(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(jt(t,e))return;n.uniform2fv(this.addr,e),Zt(t,e)}}function cx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3f(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else if(e.r!==void 0)(t[0]!==e.r||t[1]!==e.g||t[2]!==e.b)&&(n.uniform3f(this.addr,e.r,e.g,e.b),t[0]=e.r,t[1]=e.g,t[2]=e.b);else{if(jt(t,e))return;n.uniform3fv(this.addr,e),Zt(t,e)}}function ux(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4f(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(jt(t,e))return;n.uniform4fv(this.addr,e),Zt(t,e)}}function hx(n,e){const t=this.cache,i=e.elements;if(i===void 0){if(jt(t,e))return;n.uniformMatrix2fv(this.addr,!1,e),Zt(t,e)}else{if(jt(t,i))return;sd.set(i),n.uniformMatrix2fv(this.addr,!1,sd),Zt(t,i)}}function fx(n,e){const t=this.cache,i=e.elements;if(i===void 0){if(jt(t,e))return;n.uniformMatrix3fv(this.addr,!1,e),Zt(t,e)}else{if(jt(t,i))return;rd.set(i),n.uniformMatrix3fv(this.addr,!1,rd),Zt(t,i)}}function dx(n,e){const t=this.cache,i=e.elements;if(i===void 0){if(jt(t,e))return;n.uniformMatrix4fv(this.addr,!1,e),Zt(t,e)}else{if(jt(t,i))return;id.set(i),n.uniformMatrix4fv(this.addr,!1,id),Zt(t,i)}}function px(n,e){const t=this.cache;t[0]!==e&&(n.uniform1i(this.addr,e),t[0]=e)}function mx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2i(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(jt(t,e))return;n.uniform2iv(this.addr,e),Zt(t,e)}}function gx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3i(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(jt(t,e))return;n.uniform3iv(this.addr,e),Zt(t,e)}}function vx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4i(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(jt(t,e))return;n.uniform4iv(this.addr,e),Zt(t,e)}}function _x(n,e){const t=this.cache;t[0]!==e&&(n.uniform1ui(this.addr,e),t[0]=e)}function xx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(n.uniform2ui(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(jt(t,e))return;n.uniform2uiv(this.addr,e),Zt(t,e)}}function yx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(n.uniform3ui(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(jt(t,e))return;n.uniform3uiv(this.addr,e),Zt(t,e)}}function Sx(n,e){const t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(n.uniform4ui(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(jt(t,e))return;n.uniform4uiv(this.addr,e),Zt(t,e)}}function Mx(n,e,t){const i=this.cache,r=t.allocateTextureUnit();i[0]!==r&&(n.uniform1i(this.addr,r),i[0]=r);let s;this.type===n.SAMPLER_2D_SHADOW?(ed.compareFunction=G0,s=ed):s=Q0,t.setTexture2D(e||s,r)}function bx(n,e,t){const i=this.cache,r=t.allocateTextureUnit();i[0]!==r&&(n.uniform1i(this.addr,r),i[0]=r),t.setTexture3D(e||tp,r)}function wx(n,e,t){const i=this.cache,r=t.allocateTextureUnit();i[0]!==r&&(n.uniform1i(this.addr,r),i[0]=r),t.setTextureCube(e||np,r)}function Ex(n,e,t){const i=this.cache,r=t.allocateTextureUnit();i[0]!==r&&(n.uniform1i(this.addr,r),i[0]=r),t.setTexture2DArray(e||ep,r)}function Tx(n){switch(n){case 5126:return ax;case 35664:return lx;case 35665:return cx;case 35666:return ux;case 35674:return hx;case 35675:return fx;case 35676:return dx;case 5124:case 35670:return px;case 35667:case 35671:return mx;case 35668:case 35672:return gx;case 35669:case 35673:return vx;case 5125:return _x;case 36294:return xx;case 36295:return yx;case 36296:return Sx;case 35678:case 36198:case 36298:case 36306:case 35682:return Mx;case 35679:case 36299:case 36307:return bx;case 35680:case 36300:case 36308:case 36293:return wx;case 36289:case 36303:case 36311:case 36292:return Ex}}function Ax(n,e){n.uniform1fv(this.addr,e)}function Cx(n,e){const t=po(e,this.size,2);n.uniform2fv(this.addr,t)}function Rx(n,e){const t=po(e,this.size,3);n.uniform3fv(this.addr,t)}function Px(n,e){const t=po(e,this.size,4);n.uniform4fv(this.addr,t)}function Lx(n,e){const t=po(e,this.size,4);n.uniformMatrix2fv(this.addr,!1,t)}function Dx(n,e){const t=po(e,this.size,9);n.uniformMatrix3fv(this.addr,!1,t)}function Ix(n,e){const t=po(e,this.size,16);n.uniformMatrix4fv(this.addr,!1,t)}function Ux(n,e){n.uniform1iv(this.addr,e)}function Nx(n,e){n.uniform2iv(this.addr,e)}function Fx(n,e){n.uniform3iv(this.addr,e)}function Ox(n,e){n.uniform4iv(this.addr,e)}function kx(n,e){n.uniform1uiv(this.addr,e)}function Bx(n,e){n.uniform2uiv(this.addr,e)}function zx(n,e){n.uniform3uiv(this.addr,e)}function Hx(n,e){n.uniform4uiv(this.addr,e)}function Gx(n,e,t){const i=this.cache,r=e.length,s=$l(t,r);jt(i,s)||(n.uniform1iv(this.addr,s),Zt(i,s));for(let o=0;o!==r;++o)t.setTexture2D(e[o]||Q0,s[o])}function Vx(n,e,t){const i=this.cache,r=e.length,s=$l(t,r);jt(i,s)||(n.uniform1iv(this.addr,s),Zt(i,s));for(let o=0;o!==r;++o)t.setTexture3D(e[o]||tp,s[o])}function Wx(n,e,t){const i=this.cache,r=e.length,s=$l(t,r);jt(i,s)||(n.uniform1iv(this.addr,s),Zt(i,s));for(let o=0;o!==r;++o)t.setTextureCube(e[o]||np,s[o])}function Xx(n,e,t){const i=this.cache,r=e.length,s=$l(t,r);jt(i,s)||(n.uniform1iv(this.addr,s),Zt(i,s));for(let o=0;o!==r;++o)t.setTexture2DArray(e[o]||ep,s[o])}function qx(n){switch(n){case 5126:return Ax;case 35664:return Cx;case 35665:return Rx;case 35666:return Px;case 35674:return Lx;case 35675:return Dx;case 35676:return Ix;case 5124:case 35670:return Ux;case 35667:case 35671:return Nx;case 35668:case 35672:return Fx;case 35669:case 35673:return Ox;case 5125:return kx;case 36294:return Bx;case 36295:return zx;case 36296:return Hx;case 35678:case 36198:case 36298:case 36306:case 35682:return Gx;case 35679:case 36299:case 36307:return Vx;case 35680:case 36300:case 36308:case 36293:return Wx;case 36289:case 36303:case 36311:case 36292:return Xx}}class $x{constructor(e,t,i){this.id=e,this.addr=i,this.cache=[],this.type=t.type,this.setValue=Tx(t.type)}}class Yx{constructor(e,t,i){this.id=e,this.addr=i,this.cache=[],this.type=t.type,this.size=t.size,this.setValue=qx(t.type)}}class Kx{constructor(e){this.id=e,this.seq=[],this.map={}}setValue(e,t,i){const r=this.seq;for(let s=0,o=r.length;s!==o;++s){const a=r[s];a.setValue(e,t[a.id],i)}}}const Pc=/(\w+)(\])?(\[|\.)?/g;function od(n,e){n.seq.push(e),n.map[e.id]=e}function jx(n,e,t){const i=n.name,r=i.length;for(Pc.lastIndex=0;;){const s=Pc.exec(i),o=Pc.lastIndex;let a=s[1];const l=s[2]==="]",c=s[3];if(l&&(a=a|0),c===void 0||c==="["&&o+2===r){od(t,c===void 0?new $x(a,n,e):new Yx(a,n,e));break}else{let h=t.map[a];h===void 0&&(h=new Kx(a),od(t,h)),t=h}}}class hl{constructor(e,t){this.seq=[],this.map={};const i=e.getProgramParameter(t,e.ACTIVE_UNIFORMS);for(let r=0;r<i;++r){const s=e.getActiveUniform(t,r),o=e.getUniformLocation(t,s.name);jx(s,o,this)}}setValue(e,t,i,r){const s=this.map[t];s!==void 0&&s.setValue(e,i,r)}setOptional(e,t,i){const r=t[i];r!==void 0&&this.setValue(e,i,r)}static upload(e,t,i,r){for(let s=0,o=t.length;s!==o;++s){const a=t[s],l=i[a.id];l.needsUpdate!==!1&&a.setValue(e,l.value,r)}}static seqWithValue(e,t){const i=[];for(let r=0,s=e.length;r!==s;++r){const o=e[r];o.id in t&&i.push(o)}return i}}function ad(n,e,t){const i=n.createShader(e);return n.shaderSource(i,t),n.compileShader(i),i}const Zx=37297;let Jx=0;function Qx(n,e){const t=n.split(`
`),i=[],r=Math.max(e-6,0),s=Math.min(e+6,t.length);for(let o=r;o<s;o++){const a=o+1;i.push(`${a===e?">":" "} ${a}: ${t[o]}`)}return i.join(`
`)}function ey(n){const e=gt.getPrimaries(gt.workingColorSpace),t=gt.getPrimaries(n);let i;switch(e===t?i="":e===Ml&&t===Sl?i="LinearDisplayP3ToLinearSRGB":e===Sl&&t===Ml&&(i="LinearSRGBToLinearDisplayP3"),n){case wi:case Vl:return[i,"LinearTransferOETF"];case wt:case Ih:return[i,"sRGBTransferOETF"];default:return console.warn("THREE.WebGLProgram: Unsupported color space:",n),[i,"LinearTransferOETF"]}}function ld(n,e,t){const i=n.getShaderParameter(e,n.COMPILE_STATUS),r=n.getShaderInfoLog(e).trim();if(i&&r==="")return"";const s=/ERROR: 0:(\d+)/.exec(r);if(s){const o=parseInt(s[1]);return t.toUpperCase()+`

`+r+`

`+Qx(n.getShaderSource(e),o)}else return r}function ty(n,e){const t=ey(e);return`vec4 ${n}( vec4 value ) { return ${t[0]}( ${t[1]}( value ) ); }`}function ny(n,e){let t;switch(e){case ng:t="Linear";break;case ig:t="Reinhard";break;case rg:t="Cineon";break;case sg:t="ACESFilmic";break;case ag:t="AgX";break;case lg:t="Neutral";break;case og:t="Custom";break;default:console.warn("THREE.WebGLProgram: Unsupported toneMapping:",e),t="Linear"}return"vec3 "+n+"( vec3 color ) { return "+t+"ToneMapping( color ); }"}const Oa=new O;function iy(){gt.getLuminanceCoefficients(Oa);const n=Oa.x.toFixed(4),e=Oa.y.toFixed(4),t=Oa.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${n}, ${e}, ${t} );`,"	return dot( weights, rgb );","}"].join(`
`)}function ry(n){return[n.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",n.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(No).join(`
`)}function sy(n){const e=[];for(const t in n){const i=n[t];i!==!1&&e.push("#define "+t+" "+i)}return e.join(`
`)}function oy(n,e){const t={},i=n.getProgramParameter(e,n.ACTIVE_ATTRIBUTES);for(let r=0;r<i;r++){const s=n.getActiveAttrib(e,r),o=s.name;let a=1;s.type===n.FLOAT_MAT2&&(a=2),s.type===n.FLOAT_MAT3&&(a=3),s.type===n.FLOAT_MAT4&&(a=4),t[o]={type:s.type,location:n.getAttribLocation(e,o),locationSize:a}}return t}function No(n){return n!==""}function cd(n,e){const t=e.numSpotLightShadows+e.numSpotLightMaps-e.numSpotLightShadowsWithMaps;return n.replace(/NUM_DIR_LIGHTS/g,e.numDirLights).replace(/NUM_SPOT_LIGHTS/g,e.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,e.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,t).replace(/NUM_RECT_AREA_LIGHTS/g,e.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,e.numPointLights).replace(/NUM_HEMI_LIGHTS/g,e.numHemiLights).replace(/NUM_DIR_LIGHT_SHADOWS/g,e.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,e.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,e.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,e.numPointLightShadows)}function ud(n,e){return n.replace(/NUM_CLIPPING_PLANES/g,e.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,e.numClippingPlanes-e.numClipIntersection)}const ay=/^[ \t]*#include +<([\w\d./]+)>/gm;function ju(n){return n.replace(ay,cy)}const ly=new Map;function cy(n,e){let t=et[e];if(t===void 0){const i=ly.get(e);if(i!==void 0)t=et[i],console.warn('THREE.WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',e,i);else throw new Error("Can not resolve #include <"+e+">")}return ju(t)}const uy=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function hd(n){return n.replace(uy,hy)}function hy(n,e,t,i){let r="";for(let s=parseInt(e);s<parseInt(t);s++)r+=i.replace(/\[\s*i\s*\]/g,"[ "+s+" ]").replace(/UNROLLED_LOOP_INDEX/g,s);return r}function fd(n){let e=`precision ${n.precision} float;
	precision ${n.precision} int;
	precision ${n.precision} sampler2D;
	precision ${n.precision} samplerCube;
	precision ${n.precision} sampler3D;
	precision ${n.precision} sampler2DArray;
	precision ${n.precision} sampler2DShadow;
	precision ${n.precision} samplerCubeShadow;
	precision ${n.precision} sampler2DArrayShadow;
	precision ${n.precision} isampler2D;
	precision ${n.precision} isampler3D;
	precision ${n.precision} isamplerCube;
	precision ${n.precision} isampler2DArray;
	precision ${n.precision} usampler2D;
	precision ${n.precision} usampler3D;
	precision ${n.precision} usamplerCube;
	precision ${n.precision} usampler2DArray;
	`;return n.precision==="highp"?e+=`
#define HIGH_PRECISION`:n.precision==="mediump"?e+=`
#define MEDIUM_PRECISION`:n.precision==="lowp"&&(e+=`
#define LOW_PRECISION`),e}function fy(n){let e="SHADOWMAP_TYPE_BASIC";return n.shadowMapType===R0?e="SHADOWMAP_TYPE_PCF":n.shadowMapType===Nm?e="SHADOWMAP_TYPE_PCF_SOFT":n.shadowMapType===Di&&(e="SHADOWMAP_TYPE_VSM"),e}function dy(n){let e="ENVMAP_TYPE_CUBE";if(n.envMap)switch(n.envMapMode){case Qs:case eo:e="ENVMAP_TYPE_CUBE";break;case Gl:e="ENVMAP_TYPE_CUBE_UV";break}return e}function py(n){let e="ENVMAP_MODE_REFLECTION";if(n.envMap)switch(n.envMapMode){case eo:e="ENVMAP_MODE_REFRACTION";break}return e}function my(n){let e="ENVMAP_BLENDING_NONE";if(n.envMap)switch(n.combine){case P0:e="ENVMAP_BLENDING_MULTIPLY";break;case eg:e="ENVMAP_BLENDING_MIX";break;case tg:e="ENVMAP_BLENDING_ADD";break}return e}function gy(n){const e=n.envMapCubeUVHeight;if(e===null)return null;const t=Math.log2(e)-2,i=1/e;return{texelWidth:1/(3*Math.max(Math.pow(2,t),7*16)),texelHeight:i,maxMip:t}}function vy(n,e,t,i){const r=n.getContext(),s=t.defines;let o=t.vertexShader,a=t.fragmentShader;const l=fy(t),c=dy(t),u=py(t),h=my(t),f=gy(t),d=ry(t),v=sy(s),g=r.createProgram();let p,m,x=t.glslVersion?"#version "+t.glslVersion+`
`:"";t.isRawShaderMaterial?(p=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,v].filter(No).join(`
`),p.length>0&&(p+=`
`),m=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,v].filter(No).join(`
`),m.length>0&&(m+=`
`)):(p=[fd(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,v,t.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",t.batching?"#define USE_BATCHING":"",t.batchingColor?"#define USE_BATCHING_COLOR":"",t.instancing?"#define USE_INSTANCING":"",t.instancingColor?"#define USE_INSTANCING_COLOR":"",t.instancingMorph?"#define USE_INSTANCING_MORPH":"",t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.map?"#define USE_MAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+u:"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.displacementMap?"#define USE_DISPLACEMENTMAP":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.mapUv?"#define MAP_UV "+t.mapUv:"",t.alphaMapUv?"#define ALPHAMAP_UV "+t.alphaMapUv:"",t.lightMapUv?"#define LIGHTMAP_UV "+t.lightMapUv:"",t.aoMapUv?"#define AOMAP_UV "+t.aoMapUv:"",t.emissiveMapUv?"#define EMISSIVEMAP_UV "+t.emissiveMapUv:"",t.bumpMapUv?"#define BUMPMAP_UV "+t.bumpMapUv:"",t.normalMapUv?"#define NORMALMAP_UV "+t.normalMapUv:"",t.displacementMapUv?"#define DISPLACEMENTMAP_UV "+t.displacementMapUv:"",t.metalnessMapUv?"#define METALNESSMAP_UV "+t.metalnessMapUv:"",t.roughnessMapUv?"#define ROUGHNESSMAP_UV "+t.roughnessMapUv:"",t.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+t.anisotropyMapUv:"",t.clearcoatMapUv?"#define CLEARCOATMAP_UV "+t.clearcoatMapUv:"",t.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+t.clearcoatNormalMapUv:"",t.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+t.clearcoatRoughnessMapUv:"",t.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+t.iridescenceMapUv:"",t.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+t.iridescenceThicknessMapUv:"",t.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+t.sheenColorMapUv:"",t.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+t.sheenRoughnessMapUv:"",t.specularMapUv?"#define SPECULARMAP_UV "+t.specularMapUv:"",t.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+t.specularColorMapUv:"",t.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+t.specularIntensityMapUv:"",t.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+t.transmissionMapUv:"",t.thicknessMapUv?"#define THICKNESSMAP_UV "+t.thicknessMapUv:"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.flatShading?"#define FLAT_SHADED":"",t.skinning?"#define USE_SKINNING":"",t.morphTargets?"#define USE_MORPHTARGETS":"",t.morphNormals&&t.flatShading===!1?"#define USE_MORPHNORMALS":"",t.morphColors?"#define USE_MORPHCOLORS":"",t.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+t.morphTextureStride:"",t.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+t.morphTargetsCount:"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+l:"",t.sizeAttenuation?"#define USE_SIZEATTENUATION":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",t.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(No).join(`
`),m=[fd(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,v,t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",t.map?"#define USE_MAP":"",t.matcap?"#define USE_MATCAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+c:"",t.envMap?"#define "+u:"",t.envMap?"#define "+h:"",f?"#define CUBEUV_TEXEL_WIDTH "+f.texelWidth:"",f?"#define CUBEUV_TEXEL_HEIGHT "+f.texelHeight:"",f?"#define CUBEUV_MAX_MIP "+f.maxMip+".0":"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoat?"#define USE_CLEARCOAT":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.dispersion?"#define USE_DISPERSION":"",t.iridescence?"#define USE_IRIDESCENCE":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaTest?"#define USE_ALPHATEST":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.sheen?"#define USE_SHEEN":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors||t.instancingColor||t.batchingColor?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.gradientMap?"#define USE_GRADIENTMAP":"",t.flatShading?"#define FLAT_SHADED":"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+l:"",t.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",t.logarithmicDepthBuffer?"#define USE_LOGDEPTHBUF":"",t.reverseDepthBuffer?"#define USE_REVERSEDEPTHBUF":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",t.toneMapping!==ki?"#define TONE_MAPPING":"",t.toneMapping!==ki?et.tonemapping_pars_fragment:"",t.toneMapping!==ki?ny("toneMapping",t.toneMapping):"",t.dithering?"#define DITHERING":"",t.opaque?"#define OPAQUE":"",et.colorspace_pars_fragment,ty("linearToOutputTexel",t.outputColorSpace),iy(),t.useDepthPacking?"#define DEPTH_PACKING "+t.depthPacking:"",`
`].filter(No).join(`
`)),o=ju(o),o=cd(o,t),o=ud(o,t),a=ju(a),a=cd(a,t),a=ud(a,t),o=hd(o),a=hd(a),t.isRawShaderMaterial!==!0&&(x=`#version 300 es
`,p=[d,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+p,m=["#define varying in",t.glslVersion===Cf?"":"layout(location = 0) out highp vec4 pc_fragColor;",t.glslVersion===Cf?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+m);const _=x+p+o,y=x+m+a,C=ad(r,r.VERTEX_SHADER,_),M=ad(r,r.FRAGMENT_SHADER,y);r.attachShader(g,C),r.attachShader(g,M),t.index0AttributeName!==void 0?r.bindAttribLocation(g,0,t.index0AttributeName):t.morphTargets===!0&&r.bindAttribLocation(g,0,"position"),r.linkProgram(g);function w(b){if(n.debug.checkShaderErrors){const N=r.getProgramInfoLog(g).trim(),R=r.getShaderInfoLog(C).trim(),H=r.getShaderInfoLog(M).trim();let T=!0,k=!0;if(r.getProgramParameter(g,r.LINK_STATUS)===!1)if(T=!1,typeof n.debug.onShaderError=="function")n.debug.onShaderError(r,g,C,M);else{const Z=ld(r,C,"vertex"),K=ld(r,M,"fragment");console.error("THREE.WebGLProgram: Shader Error "+r.getError()+" - VALIDATE_STATUS "+r.getProgramParameter(g,r.VALIDATE_STATUS)+`

Material Name: `+b.name+`
Material Type: `+b.type+`

Program Info Log: `+N+`
`+Z+`
`+K)}else N!==""?console.warn("THREE.WebGLProgram: Program Info Log:",N):(R===""||H==="")&&(k=!1);k&&(b.diagnostics={runnable:T,programLog:N,vertexShader:{log:R,prefix:p},fragmentShader:{log:H,prefix:m}})}r.deleteShader(C),r.deleteShader(M),P=new hl(r,g),I=oy(r,g)}let P;this.getUniforms=function(){return P===void 0&&w(this),P};let I;this.getAttributes=function(){return I===void 0&&w(this),I};let S=t.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return S===!1&&(S=r.getProgramParameter(g,Zx)),S},this.destroy=function(){i.releaseStatesOfProgram(this),r.deleteProgram(g),this.program=void 0},this.type=t.shaderType,this.name=t.shaderName,this.id=Jx++,this.cacheKey=e,this.usedTimes=1,this.program=g,this.vertexShader=C,this.fragmentShader=M,this}let _y=0;class xy{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(e){const t=e.vertexShader,i=e.fragmentShader,r=this._getShaderStage(t),s=this._getShaderStage(i),o=this._getShaderCacheForMaterial(e);return o.has(r)===!1&&(o.add(r),r.usedTimes++),o.has(s)===!1&&(o.add(s),s.usedTimes++),this}remove(e){const t=this.materialCache.get(e);for(const i of t)i.usedTimes--,i.usedTimes===0&&this.shaderCache.delete(i.code);return this.materialCache.delete(e),this}getVertexShaderID(e){return this._getShaderStage(e.vertexShader).id}getFragmentShaderID(e){return this._getShaderStage(e.fragmentShader).id}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(e){const t=this.materialCache;let i=t.get(e);return i===void 0&&(i=new Set,t.set(e,i)),i}_getShaderStage(e){const t=this.shaderCache;let i=t.get(e);return i===void 0&&(i=new yy(e),t.set(e,i)),i}}class yy{constructor(e){this.id=_y++,this.code=e,this.usedTimes=0}}function Sy(n,e,t,i,r,s,o){const a=new q0,l=new xy,c=new Set,u=[],h=r.logarithmicDepthBuffer,f=r.reverseDepthBuffer,d=r.vertexTextures;let v=r.precision;const g={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distanceRGBA",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function p(S){return c.add(S),S===0?"uv":`uv${S}`}function m(S,b,N,R,H){const T=R.fog,k=H.geometry,Z=S.isMeshStandardMaterial?R.environment:null,K=(S.isMeshStandardMaterial?t:e).get(S.envMap||Z),pe=K&&K.mapping===Gl?K.image.height:null,ce=g[S.type];S.precision!==null&&(v=r.getMaxPrecision(S.precision),v!==S.precision&&console.warn("THREE.WebGLProgram.getParameters:",S.precision,"not supported, using",v,"instead."));const W=k.morphAttributes.position||k.morphAttributes.normal||k.morphAttributes.color,re=W!==void 0?W.length:0;let Ae=0;k.morphAttributes.position!==void 0&&(Ae=1),k.morphAttributes.normal!==void 0&&(Ae=2),k.morphAttributes.color!==void 0&&(Ae=3);let ee,F,xe,G;if(ce){const yt=gi[ce];ee=yt.vertexShader,F=yt.fragmentShader}else ee=S.vertexShader,F=S.fragmentShader,l.update(S),xe=l.getVertexShaderID(S),G=l.getFragmentShaderID(S);const he=n.getRenderTarget(),me=H.isInstancedMesh===!0,fe=H.isBatchedMesh===!0,De=!!S.map,se=!!S.matcap,U=!!K,Se=!!S.aoMap,ye=!!S.lightMap,ge=!!S.bumpMap,B=!!S.normalMap,q=!!S.displacementMap,V=!!S.emissiveMap,A=!!S.metalnessMap,E=!!S.roughnessMap,z=S.anisotropy>0,$=S.clearcoat>0,ne=S.dispersion>0,te=S.iridescence>0,ve=S.sheen>0,ue=S.transmission>0,Me=z&&!!S.anisotropyMap,Re=$&&!!S.clearcoatMap,de=$&&!!S.clearcoatNormalMap,Ee=$&&!!S.clearcoatRoughnessMap,Ne=te&&!!S.iridescenceMap,Ve=te&&!!S.iridescenceThicknessMap,Pe=ve&&!!S.sheenColorMap,Xe=ve&&!!S.sheenRoughnessMap,We=!!S.specularMap,dt=!!S.specularColorMap,X=!!S.specularIntensityMap,ie=ue&&!!S.transmissionMap,Q=ue&&!!S.thicknessMap,le=!!S.gradientMap,Te=!!S.alphaMap,_e=S.alphaTest>0,qe=!!S.alphaHash,rt=!!S.extensions;let Lt=ki;S.toneMapped&&(he===null||he.isXRRenderTarget===!0)&&(Lt=n.toneMapping);const Je={shaderID:ce,shaderType:S.type,shaderName:S.name,vertexShader:ee,fragmentShader:F,defines:S.defines,customVertexShaderID:xe,customFragmentShaderID:G,isRawShaderMaterial:S.isRawShaderMaterial===!0,glslVersion:S.glslVersion,precision:v,batching:fe,batchingColor:fe&&H._colorsTexture!==null,instancing:me,instancingColor:me&&H.instanceColor!==null,instancingMorph:me&&H.morphTexture!==null,supportsVertexTextures:d,outputColorSpace:he===null?n.outputColorSpace:he.isXRRenderTarget===!0?he.texture.colorSpace:wi,alphaToCoverage:!!S.alphaToCoverage,map:De,matcap:se,envMap:U,envMapMode:U&&K.mapping,envMapCubeUVHeight:pe,aoMap:Se,lightMap:ye,bumpMap:ge,normalMap:B,displacementMap:d&&q,emissiveMap:V,normalMapObjectSpace:B&&S.normalMapType===fg,normalMapTangentSpace:B&&S.normalMapType===hg,metalnessMap:A,roughnessMap:E,anisotropy:z,anisotropyMap:Me,clearcoat:$,clearcoatMap:Re,clearcoatNormalMap:de,clearcoatRoughnessMap:Ee,dispersion:ne,iridescence:te,iridescenceMap:Ne,iridescenceThicknessMap:Ve,sheen:ve,sheenColorMap:Pe,sheenRoughnessMap:Xe,specularMap:We,specularColorMap:dt,specularIntensityMap:X,transmission:ue,transmissionMap:ie,thicknessMap:Q,gradientMap:le,opaque:S.transparent===!1&&S.blending===Ws&&S.alphaToCoverage===!1,alphaMap:Te,alphaTest:_e,alphaHash:qe,combine:S.combine,mapUv:De&&p(S.map.channel),aoMapUv:Se&&p(S.aoMap.channel),lightMapUv:ye&&p(S.lightMap.channel),bumpMapUv:ge&&p(S.bumpMap.channel),normalMapUv:B&&p(S.normalMap.channel),displacementMapUv:q&&p(S.displacementMap.channel),emissiveMapUv:V&&p(S.emissiveMap.channel),metalnessMapUv:A&&p(S.metalnessMap.channel),roughnessMapUv:E&&p(S.roughnessMap.channel),anisotropyMapUv:Me&&p(S.anisotropyMap.channel),clearcoatMapUv:Re&&p(S.clearcoatMap.channel),clearcoatNormalMapUv:de&&p(S.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:Ee&&p(S.clearcoatRoughnessMap.channel),iridescenceMapUv:Ne&&p(S.iridescenceMap.channel),iridescenceThicknessMapUv:Ve&&p(S.iridescenceThicknessMap.channel),sheenColorMapUv:Pe&&p(S.sheenColorMap.channel),sheenRoughnessMapUv:Xe&&p(S.sheenRoughnessMap.channel),specularMapUv:We&&p(S.specularMap.channel),specularColorMapUv:dt&&p(S.specularColorMap.channel),specularIntensityMapUv:X&&p(S.specularIntensityMap.channel),transmissionMapUv:ie&&p(S.transmissionMap.channel),thicknessMapUv:Q&&p(S.thicknessMap.channel),alphaMapUv:Te&&p(S.alphaMap.channel),vertexTangents:!!k.attributes.tangent&&(B||z),vertexColors:S.vertexColors,vertexAlphas:S.vertexColors===!0&&!!k.attributes.color&&k.attributes.color.itemSize===4,pointsUvs:H.isPoints===!0&&!!k.attributes.uv&&(De||Te),fog:!!T,useFog:S.fog===!0,fogExp2:!!T&&T.isFogExp2,flatShading:S.flatShading===!0,sizeAttenuation:S.sizeAttenuation===!0,logarithmicDepthBuffer:h,reverseDepthBuffer:f,skinning:H.isSkinnedMesh===!0,morphTargets:k.morphAttributes.position!==void 0,morphNormals:k.morphAttributes.normal!==void 0,morphColors:k.morphAttributes.color!==void 0,morphTargetsCount:re,morphTextureStride:Ae,numDirLights:b.directional.length,numPointLights:b.point.length,numSpotLights:b.spot.length,numSpotLightMaps:b.spotLightMap.length,numRectAreaLights:b.rectArea.length,numHemiLights:b.hemi.length,numDirLightShadows:b.directionalShadowMap.length,numPointLightShadows:b.pointShadowMap.length,numSpotLightShadows:b.spotShadowMap.length,numSpotLightShadowsWithMaps:b.numSpotLightShadowsWithMaps,numLightProbes:b.numLightProbes,numClippingPlanes:o.numPlanes,numClipIntersection:o.numIntersection,dithering:S.dithering,shadowMapEnabled:n.shadowMap.enabled&&N.length>0,shadowMapType:n.shadowMap.type,toneMapping:Lt,decodeVideoTexture:De&&S.map.isVideoTexture===!0&&gt.getTransfer(S.map.colorSpace)===Pt,premultipliedAlpha:S.premultipliedAlpha,doubleSided:S.side===Tn,flipSided:S.side===Kt,useDepthPacking:S.depthPacking>=0,depthPacking:S.depthPacking||0,index0AttributeName:S.index0AttributeName,extensionClipCullDistance:rt&&S.extensions.clipCullDistance===!0&&i.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(rt&&S.extensions.multiDraw===!0||fe)&&i.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:i.has("KHR_parallel_shader_compile"),customProgramCacheKey:S.customProgramCacheKey()};return Je.vertexUv1s=c.has(1),Je.vertexUv2s=c.has(2),Je.vertexUv3s=c.has(3),c.clear(),Je}function x(S){const b=[];if(S.shaderID?b.push(S.shaderID):(b.push(S.customVertexShaderID),b.push(S.customFragmentShaderID)),S.defines!==void 0)for(const N in S.defines)b.push(N),b.push(S.defines[N]);return S.isRawShaderMaterial===!1&&(_(b,S),y(b,S),b.push(n.outputColorSpace)),b.push(S.customProgramCacheKey),b.join()}function _(S,b){S.push(b.precision),S.push(b.outputColorSpace),S.push(b.envMapMode),S.push(b.envMapCubeUVHeight),S.push(b.mapUv),S.push(b.alphaMapUv),S.push(b.lightMapUv),S.push(b.aoMapUv),S.push(b.bumpMapUv),S.push(b.normalMapUv),S.push(b.displacementMapUv),S.push(b.emissiveMapUv),S.push(b.metalnessMapUv),S.push(b.roughnessMapUv),S.push(b.anisotropyMapUv),S.push(b.clearcoatMapUv),S.push(b.clearcoatNormalMapUv),S.push(b.clearcoatRoughnessMapUv),S.push(b.iridescenceMapUv),S.push(b.iridescenceThicknessMapUv),S.push(b.sheenColorMapUv),S.push(b.sheenRoughnessMapUv),S.push(b.specularMapUv),S.push(b.specularColorMapUv),S.push(b.specularIntensityMapUv),S.push(b.transmissionMapUv),S.push(b.thicknessMapUv),S.push(b.combine),S.push(b.fogExp2),S.push(b.sizeAttenuation),S.push(b.morphTargetsCount),S.push(b.morphAttributeCount),S.push(b.numDirLights),S.push(b.numPointLights),S.push(b.numSpotLights),S.push(b.numSpotLightMaps),S.push(b.numHemiLights),S.push(b.numRectAreaLights),S.push(b.numDirLightShadows),S.push(b.numPointLightShadows),S.push(b.numSpotLightShadows),S.push(b.numSpotLightShadowsWithMaps),S.push(b.numLightProbes),S.push(b.shadowMapType),S.push(b.toneMapping),S.push(b.numClippingPlanes),S.push(b.numClipIntersection),S.push(b.depthPacking)}function y(S,b){a.disableAll(),b.supportsVertexTextures&&a.enable(0),b.instancing&&a.enable(1),b.instancingColor&&a.enable(2),b.instancingMorph&&a.enable(3),b.matcap&&a.enable(4),b.envMap&&a.enable(5),b.normalMapObjectSpace&&a.enable(6),b.normalMapTangentSpace&&a.enable(7),b.clearcoat&&a.enable(8),b.iridescence&&a.enable(9),b.alphaTest&&a.enable(10),b.vertexColors&&a.enable(11),b.vertexAlphas&&a.enable(12),b.vertexUv1s&&a.enable(13),b.vertexUv2s&&a.enable(14),b.vertexUv3s&&a.enable(15),b.vertexTangents&&a.enable(16),b.anisotropy&&a.enable(17),b.alphaHash&&a.enable(18),b.batching&&a.enable(19),b.dispersion&&a.enable(20),b.batchingColor&&a.enable(21),S.push(a.mask),a.disableAll(),b.fog&&a.enable(0),b.useFog&&a.enable(1),b.flatShading&&a.enable(2),b.logarithmicDepthBuffer&&a.enable(3),b.reverseDepthBuffer&&a.enable(4),b.skinning&&a.enable(5),b.morphTargets&&a.enable(6),b.morphNormals&&a.enable(7),b.morphColors&&a.enable(8),b.premultipliedAlpha&&a.enable(9),b.shadowMapEnabled&&a.enable(10),b.doubleSided&&a.enable(11),b.flipSided&&a.enable(12),b.useDepthPacking&&a.enable(13),b.dithering&&a.enable(14),b.transmission&&a.enable(15),b.sheen&&a.enable(16),b.opaque&&a.enable(17),b.pointsUvs&&a.enable(18),b.decodeVideoTexture&&a.enable(19),b.alphaToCoverage&&a.enable(20),S.push(a.mask)}function C(S){const b=g[S.type];let N;if(b){const R=gi[b];N=iv.clone(R.uniforms)}else N=S.uniforms;return N}function M(S,b){let N;for(let R=0,H=u.length;R<H;R++){const T=u[R];if(T.cacheKey===b){N=T,++N.usedTimes;break}}return N===void 0&&(N=new vy(n,b,S,s),u.push(N)),N}function w(S){if(--S.usedTimes===0){const b=u.indexOf(S);u[b]=u[u.length-1],u.pop(),S.destroy()}}function P(S){l.remove(S)}function I(){l.dispose()}return{getParameters:m,getProgramCacheKey:x,getUniforms:C,acquireProgram:M,releaseProgram:w,releaseShaderCache:P,programs:u,dispose:I}}function My(){let n=new WeakMap;function e(o){return n.has(o)}function t(o){let a=n.get(o);return a===void 0&&(a={},n.set(o,a)),a}function i(o){n.delete(o)}function r(o,a,l){n.get(o)[a]=l}function s(){n=new WeakMap}return{has:e,get:t,remove:i,update:r,dispose:s}}function by(n,e){return n.groupOrder!==e.groupOrder?n.groupOrder-e.groupOrder:n.renderOrder!==e.renderOrder?n.renderOrder-e.renderOrder:n.material.id!==e.material.id?n.material.id-e.material.id:n.z!==e.z?n.z-e.z:n.id-e.id}function dd(n,e){return n.groupOrder!==e.groupOrder?n.groupOrder-e.groupOrder:n.renderOrder!==e.renderOrder?n.renderOrder-e.renderOrder:n.z!==e.z?e.z-n.z:n.id-e.id}function pd(){const n=[];let e=0;const t=[],i=[],r=[];function s(){e=0,t.length=0,i.length=0,r.length=0}function o(h,f,d,v,g,p){let m=n[e];return m===void 0?(m={id:h.id,object:h,geometry:f,material:d,groupOrder:v,renderOrder:h.renderOrder,z:g,group:p},n[e]=m):(m.id=h.id,m.object=h,m.geometry=f,m.material=d,m.groupOrder=v,m.renderOrder=h.renderOrder,m.z=g,m.group=p),e++,m}function a(h,f,d,v,g,p){const m=o(h,f,d,v,g,p);d.transmission>0?i.push(m):d.transparent===!0?r.push(m):t.push(m)}function l(h,f,d,v,g,p){const m=o(h,f,d,v,g,p);d.transmission>0?i.unshift(m):d.transparent===!0?r.unshift(m):t.unshift(m)}function c(h,f){t.length>1&&t.sort(h||by),i.length>1&&i.sort(f||dd),r.length>1&&r.sort(f||dd)}function u(){for(let h=e,f=n.length;h<f;h++){const d=n[h];if(d.id===null)break;d.id=null,d.object=null,d.geometry=null,d.material=null,d.group=null}}return{opaque:t,transmissive:i,transparent:r,init:s,push:a,unshift:l,finish:u,sort:c}}function wy(){let n=new WeakMap;function e(i,r){const s=n.get(i);let o;return s===void 0?(o=new pd,n.set(i,[o])):r>=s.length?(o=new pd,s.push(o)):o=s[r],o}function t(){n=new WeakMap}return{get:e,dispose:t}}function Ey(){const n={};return{get:function(e){if(n[e.id]!==void 0)return n[e.id];let t;switch(e.type){case"DirectionalLight":t={direction:new O,color:new st};break;case"SpotLight":t={position:new O,direction:new O,color:new st,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":t={position:new O,color:new st,distance:0,decay:0};break;case"HemisphereLight":t={direction:new O,skyColor:new st,groundColor:new st};break;case"RectAreaLight":t={color:new st,position:new O,halfWidth:new O,halfHeight:new O};break}return n[e.id]=t,t}}}function Ty(){const n={};return{get:function(e){if(n[e.id]!==void 0)return n[e.id];let t;switch(e.type){case"DirectionalLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new we};break;case"SpotLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new we};break;case"PointLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new we,shadowCameraNear:1,shadowCameraFar:1e3};break}return n[e.id]=t,t}}}let Ay=0;function Cy(n,e){return(e.castShadow?2:0)-(n.castShadow?2:0)+(e.map?1:0)-(n.map?1:0)}function Ry(n){const e=new Ey,t=Ty(),i={version:0,hash:{directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let c=0;c<9;c++)i.probe.push(new O);const r=new O,s=new It,o=new It;function a(c){let u=0,h=0,f=0;for(let I=0;I<9;I++)i.probe[I].set(0,0,0);let d=0,v=0,g=0,p=0,m=0,x=0,_=0,y=0,C=0,M=0,w=0;c.sort(Cy);for(let I=0,S=c.length;I<S;I++){const b=c[I],N=b.color,R=b.intensity,H=b.distance,T=b.shadow&&b.shadow.map?b.shadow.map.texture:null;if(b.isAmbientLight)u+=N.r*R,h+=N.g*R,f+=N.b*R;else if(b.isLightProbe){for(let k=0;k<9;k++)i.probe[k].addScaledVector(b.sh.coefficients[k],R);w++}else if(b.isDirectionalLight){const k=e.get(b);if(k.color.copy(b.color).multiplyScalar(b.intensity),b.castShadow){const Z=b.shadow,K=t.get(b);K.shadowIntensity=Z.intensity,K.shadowBias=Z.bias,K.shadowNormalBias=Z.normalBias,K.shadowRadius=Z.radius,K.shadowMapSize=Z.mapSize,i.directionalShadow[d]=K,i.directionalShadowMap[d]=T,i.directionalShadowMatrix[d]=b.shadow.matrix,x++}i.directional[d]=k,d++}else if(b.isSpotLight){const k=e.get(b);k.position.setFromMatrixPosition(b.matrixWorld),k.color.copy(N).multiplyScalar(R),k.distance=H,k.coneCos=Math.cos(b.angle),k.penumbraCos=Math.cos(b.angle*(1-b.penumbra)),k.decay=b.decay,i.spot[g]=k;const Z=b.shadow;if(b.map&&(i.spotLightMap[C]=b.map,C++,Z.updateMatrices(b),b.castShadow&&M++),i.spotLightMatrix[g]=Z.matrix,b.castShadow){const K=t.get(b);K.shadowIntensity=Z.intensity,K.shadowBias=Z.bias,K.shadowNormalBias=Z.normalBias,K.shadowRadius=Z.radius,K.shadowMapSize=Z.mapSize,i.spotShadow[g]=K,i.spotShadowMap[g]=T,y++}g++}else if(b.isRectAreaLight){const k=e.get(b);k.color.copy(N).multiplyScalar(R),k.halfWidth.set(b.width*.5,0,0),k.halfHeight.set(0,b.height*.5,0),i.rectArea[p]=k,p++}else if(b.isPointLight){const k=e.get(b);if(k.color.copy(b.color).multiplyScalar(b.intensity),k.distance=b.distance,k.decay=b.decay,b.castShadow){const Z=b.shadow,K=t.get(b);K.shadowIntensity=Z.intensity,K.shadowBias=Z.bias,K.shadowNormalBias=Z.normalBias,K.shadowRadius=Z.radius,K.shadowMapSize=Z.mapSize,K.shadowCameraNear=Z.camera.near,K.shadowCameraFar=Z.camera.far,i.pointShadow[v]=K,i.pointShadowMap[v]=T,i.pointShadowMatrix[v]=b.shadow.matrix,_++}i.point[v]=k,v++}else if(b.isHemisphereLight){const k=e.get(b);k.skyColor.copy(b.color).multiplyScalar(R),k.groundColor.copy(b.groundColor).multiplyScalar(R),i.hemi[m]=k,m++}}p>0&&(n.has("OES_texture_float_linear")===!0?(i.rectAreaLTC1=Ie.LTC_FLOAT_1,i.rectAreaLTC2=Ie.LTC_FLOAT_2):(i.rectAreaLTC1=Ie.LTC_HALF_1,i.rectAreaLTC2=Ie.LTC_HALF_2)),i.ambient[0]=u,i.ambient[1]=h,i.ambient[2]=f;const P=i.hash;(P.directionalLength!==d||P.pointLength!==v||P.spotLength!==g||P.rectAreaLength!==p||P.hemiLength!==m||P.numDirectionalShadows!==x||P.numPointShadows!==_||P.numSpotShadows!==y||P.numSpotMaps!==C||P.numLightProbes!==w)&&(i.directional.length=d,i.spot.length=g,i.rectArea.length=p,i.point.length=v,i.hemi.length=m,i.directionalShadow.length=x,i.directionalShadowMap.length=x,i.pointShadow.length=_,i.pointShadowMap.length=_,i.spotShadow.length=y,i.spotShadowMap.length=y,i.directionalShadowMatrix.length=x,i.pointShadowMatrix.length=_,i.spotLightMatrix.length=y+C-M,i.spotLightMap.length=C,i.numSpotLightShadowsWithMaps=M,i.numLightProbes=w,P.directionalLength=d,P.pointLength=v,P.spotLength=g,P.rectAreaLength=p,P.hemiLength=m,P.numDirectionalShadows=x,P.numPointShadows=_,P.numSpotShadows=y,P.numSpotMaps=C,P.numLightProbes=w,i.version=Ay++)}function l(c,u){let h=0,f=0,d=0,v=0,g=0;const p=u.matrixWorldInverse;for(let m=0,x=c.length;m<x;m++){const _=c[m];if(_.isDirectionalLight){const y=i.directional[h];y.direction.setFromMatrixPosition(_.matrixWorld),r.setFromMatrixPosition(_.target.matrixWorld),y.direction.sub(r),y.direction.transformDirection(p),h++}else if(_.isSpotLight){const y=i.spot[d];y.position.setFromMatrixPosition(_.matrixWorld),y.position.applyMatrix4(p),y.direction.setFromMatrixPosition(_.matrixWorld),r.setFromMatrixPosition(_.target.matrixWorld),y.direction.sub(r),y.direction.transformDirection(p),d++}else if(_.isRectAreaLight){const y=i.rectArea[v];y.position.setFromMatrixPosition(_.matrixWorld),y.position.applyMatrix4(p),o.identity(),s.copy(_.matrixWorld),s.premultiply(p),o.extractRotation(s),y.halfWidth.set(_.width*.5,0,0),y.halfHeight.set(0,_.height*.5,0),y.halfWidth.applyMatrix4(o),y.halfHeight.applyMatrix4(o),v++}else if(_.isPointLight){const y=i.point[f];y.position.setFromMatrixPosition(_.matrixWorld),y.position.applyMatrix4(p),f++}else if(_.isHemisphereLight){const y=i.hemi[g];y.direction.setFromMatrixPosition(_.matrixWorld),y.direction.transformDirection(p),g++}}}return{setup:a,setupView:l,state:i}}function md(n){const e=new Ry(n),t=[],i=[];function r(u){c.camera=u,t.length=0,i.length=0}function s(u){t.push(u)}function o(u){i.push(u)}function a(){e.setup(t)}function l(u){e.setupView(t,u)}const c={lightsArray:t,shadowsArray:i,camera:null,lights:e,transmissionRenderTarget:{}};return{init:r,state:c,setupLights:a,setupLightsView:l,pushLight:s,pushShadow:o}}function Py(n){let e=new WeakMap;function t(r,s=0){const o=e.get(r);let a;return o===void 0?(a=new md(n),e.set(r,[a])):s>=o.length?(a=new md(n),o.push(a)):a=o[s],a}function i(){e=new WeakMap}return{get:t,dispose:i}}class Ly extends os{constructor(e){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=ha,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(e)}copy(e){return super.copy(e),this.depthPacking=e.depthPacking,this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this}}class Dy extends os{constructor(e){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(e)}copy(e){return super.copy(e),this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this}}const Iy=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,Uy=`uniform sampler2D shadow_pass;
uniform vec2 resolution;
uniform float radius;
#include <packing>
void main() {
	const float samples = float( VSM_SAMPLES );
	float mean = 0.0;
	float squared_mean = 0.0;
	float uvStride = samples <= 1.0 ? 0.0 : 2.0 / ( samples - 1.0 );
	float uvStart = samples <= 1.0 ? 0.0 : - 1.0;
	for ( float i = 0.0; i < samples; i ++ ) {
		float uvOffset = uvStart + i * uvStride;
		#ifdef HORIZONTAL_PASS
			vec2 distribution = unpackRGBATo2Half( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( uvOffset, 0.0 ) * radius ) / resolution ) );
			mean += distribution.x;
			squared_mean += distribution.y * distribution.y + distribution.x * distribution.x;
		#else
			float depth = unpackRGBAToDepth( texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( 0.0, uvOffset ) * radius ) / resolution ) );
			mean += depth;
			squared_mean += depth * depth;
		#endif
	}
	mean = mean / samples;
	squared_mean = squared_mean / samples;
	float std_dev = sqrt( squared_mean - mean * mean );
	gl_FragColor = pack2HalfToRGBA( vec2( mean, std_dev ) );
}`;function Ny(n,e,t){let i=new Z0;const r=new we,s=new we,o=new Ct,a=new Ly({depthPacking:ug}),l=new Dy,c={},u=t.maxTextureSize,h={[zi]:Kt,[Kt]:zi,[Tn]:Tn},f=new xt({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new we},radius:{value:4}},vertexShader:Iy,fragmentShader:Uy}),d=f.clone();d.defines.HORIZONTAL_PASS=1;const v=new Et;v.setAttribute("position",new kt(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));const g=new Gt(v,f),p=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=R0;let m=this.type;this.render=function(M,w,P){if(p.enabled===!1||p.autoUpdate===!1&&p.needsUpdate===!1||M.length===0)return;const I=n.getRenderTarget(),S=n.getActiveCubeFace(),b=n.getActiveMipmapLevel(),N=n.state;N.setBlending(An),N.buffers.color.setClear(1,1,1,1),N.buffers.depth.setTest(!0),N.setScissorTest(!1);const R=m!==Di&&this.type===Di,H=m===Di&&this.type!==Di;for(let T=0,k=M.length;T<k;T++){const Z=M[T],K=Z.shadow;if(K===void 0){console.warn("THREE.WebGLShadowMap:",Z,"has no shadow.");continue}if(K.autoUpdate===!1&&K.needsUpdate===!1)continue;r.copy(K.mapSize);const pe=K.getFrameExtents();if(r.multiply(pe),s.copy(K.mapSize),(r.x>u||r.y>u)&&(r.x>u&&(s.x=Math.floor(u/pe.x),r.x=s.x*pe.x,K.mapSize.x=s.x),r.y>u&&(s.y=Math.floor(u/pe.y),r.y=s.y*pe.y,K.mapSize.y=s.y)),K.map===null||R===!0||H===!0){const W=this.type!==Di?{minFilter:dn,magFilter:dn}:{};K.map!==null&&K.map.dispose(),K.map=new Sn(r.x,r.y,W),K.map.texture.name=Z.name+".shadowMap",K.camera.updateProjectionMatrix()}n.setRenderTarget(K.map),n.clear();const ce=K.getViewportCount();for(let W=0;W<ce;W++){const re=K.getViewport(W);o.set(s.x*re.x,s.y*re.y,s.x*re.z,s.y*re.w),N.viewport(o),K.updateMatrices(Z,W),i=K.getFrustum(),y(w,P,K.camera,Z,this.type)}K.isPointLightShadow!==!0&&this.type===Di&&x(K,P),K.needsUpdate=!1}m=this.type,p.needsUpdate=!1,n.setRenderTarget(I,S,b)};function x(M,w){const P=e.update(g);f.defines.VSM_SAMPLES!==M.blurSamples&&(f.defines.VSM_SAMPLES=M.blurSamples,d.defines.VSM_SAMPLES=M.blurSamples,f.needsUpdate=!0,d.needsUpdate=!0),M.mapPass===null&&(M.mapPass=new Sn(r.x,r.y)),f.uniforms.shadow_pass.value=M.map.texture,f.uniforms.resolution.value=M.mapSize,f.uniforms.radius.value=M.radius,n.setRenderTarget(M.mapPass),n.clear(),n.renderBufferDirect(w,null,P,f,g,null),d.uniforms.shadow_pass.value=M.mapPass.texture,d.uniforms.resolution.value=M.mapSize,d.uniforms.radius.value=M.radius,n.setRenderTarget(M.map),n.clear(),n.renderBufferDirect(w,null,P,d,g,null)}function _(M,w,P,I){let S=null;const b=P.isPointLight===!0?M.customDistanceMaterial:M.customDepthMaterial;if(b!==void 0)S=b;else if(S=P.isPointLight===!0?l:a,n.localClippingEnabled&&w.clipShadows===!0&&Array.isArray(w.clippingPlanes)&&w.clippingPlanes.length!==0||w.displacementMap&&w.displacementScale!==0||w.alphaMap&&w.alphaTest>0||w.map&&w.alphaTest>0){const N=S.uuid,R=w.uuid;let H=c[N];H===void 0&&(H={},c[N]=H);let T=H[R];T===void 0&&(T=S.clone(),H[R]=T,w.addEventListener("dispose",C)),S=T}if(S.visible=w.visible,S.wireframe=w.wireframe,I===Di?S.side=w.shadowSide!==null?w.shadowSide:w.side:S.side=w.shadowSide!==null?w.shadowSide:h[w.side],S.alphaMap=w.alphaMap,S.alphaTest=w.alphaTest,S.map=w.map,S.clipShadows=w.clipShadows,S.clippingPlanes=w.clippingPlanes,S.clipIntersection=w.clipIntersection,S.displacementMap=w.displacementMap,S.displacementScale=w.displacementScale,S.displacementBias=w.displacementBias,S.wireframeLinewidth=w.wireframeLinewidth,S.linewidth=w.linewidth,P.isPointLight===!0&&S.isMeshDistanceMaterial===!0){const N=n.properties.get(S);N.light=P}return S}function y(M,w,P,I,S){if(M.visible===!1)return;if(M.layers.test(w.layers)&&(M.isMesh||M.isLine||M.isPoints)&&(M.castShadow||M.receiveShadow&&S===Di)&&(!M.frustumCulled||i.intersectsObject(M))){M.modelViewMatrix.multiplyMatrices(P.matrixWorldInverse,M.matrixWorld);const R=e.update(M),H=M.material;if(Array.isArray(H)){const T=R.groups;for(let k=0,Z=T.length;k<Z;k++){const K=T[k],pe=H[K.materialIndex];if(pe&&pe.visible){const ce=_(M,pe,I,S);M.onBeforeShadow(n,M,w,P,R,ce,K),n.renderBufferDirect(P,null,R,ce,M,K),M.onAfterShadow(n,M,w,P,R,ce,K)}}}else if(H.visible){const T=_(M,H,I,S);M.onBeforeShadow(n,M,w,P,R,T,null),n.renderBufferDirect(P,null,R,T,M,null),M.onAfterShadow(n,M,w,P,R,T,null)}}const N=M.children;for(let R=0,H=N.length;R<H;R++)y(N[R],w,P,I,S)}function C(M){M.target.removeEventListener("dispose",C);for(const P in c){const I=c[P],S=M.target.uuid;S in I&&(I[S].dispose(),delete I[S])}}}const Fy={[pu]:mu,[gu]:xu,[vu]:yu,[Js]:_u,[mu]:pu,[xu]:gu,[yu]:vu,[_u]:Js};function Oy(n){function e(){let X=!1;const ie=new Ct;let Q=null;const le=new Ct(0,0,0,0);return{setMask:function(Te){Q!==Te&&!X&&(n.colorMask(Te,Te,Te,Te),Q=Te)},setLocked:function(Te){X=Te},setClear:function(Te,_e,qe,rt,Lt){Lt===!0&&(Te*=rt,_e*=rt,qe*=rt),ie.set(Te,_e,qe,rt),le.equals(ie)===!1&&(n.clearColor(Te,_e,qe,rt),le.copy(ie))},reset:function(){X=!1,Q=null,le.set(-1,0,0,0)}}}function t(){let X=!1,ie=!1,Q=null,le=null,Te=null;return{setReversed:function(_e){ie=_e},setTest:function(_e){_e?xe(n.DEPTH_TEST):G(n.DEPTH_TEST)},setMask:function(_e){Q!==_e&&!X&&(n.depthMask(_e),Q=_e)},setFunc:function(_e){if(ie&&(_e=Fy[_e]),le!==_e){switch(_e){case pu:n.depthFunc(n.NEVER);break;case mu:n.depthFunc(n.ALWAYS);break;case gu:n.depthFunc(n.LESS);break;case Js:n.depthFunc(n.LEQUAL);break;case vu:n.depthFunc(n.EQUAL);break;case _u:n.depthFunc(n.GEQUAL);break;case xu:n.depthFunc(n.GREATER);break;case yu:n.depthFunc(n.NOTEQUAL);break;default:n.depthFunc(n.LEQUAL)}le=_e}},setLocked:function(_e){X=_e},setClear:function(_e){Te!==_e&&(n.clearDepth(_e),Te=_e)},reset:function(){X=!1,Q=null,le=null,Te=null}}}function i(){let X=!1,ie=null,Q=null,le=null,Te=null,_e=null,qe=null,rt=null,Lt=null;return{setTest:function(Je){X||(Je?xe(n.STENCIL_TEST):G(n.STENCIL_TEST))},setMask:function(Je){ie!==Je&&!X&&(n.stencilMask(Je),ie=Je)},setFunc:function(Je,yt,Jt){(Q!==Je||le!==yt||Te!==Jt)&&(n.stencilFunc(Je,yt,Jt),Q=Je,le=yt,Te=Jt)},setOp:function(Je,yt,Jt){(_e!==Je||qe!==yt||rt!==Jt)&&(n.stencilOp(Je,yt,Jt),_e=Je,qe=yt,rt=Jt)},setLocked:function(Je){X=Je},setClear:function(Je){Lt!==Je&&(n.clearStencil(Je),Lt=Je)},reset:function(){X=!1,ie=null,Q=null,le=null,Te=null,_e=null,qe=null,rt=null,Lt=null}}}const r=new e,s=new t,o=new i,a=new WeakMap,l=new WeakMap;let c={},u={},h=new WeakMap,f=[],d=null,v=!1,g=null,p=null,m=null,x=null,_=null,y=null,C=null,M=new st(0,0,0),w=0,P=!1,I=null,S=null,b=null,N=null,R=null;const H=n.getParameter(n.MAX_COMBINED_TEXTURE_IMAGE_UNITS);let T=!1,k=0;const Z=n.getParameter(n.VERSION);Z.indexOf("WebGL")!==-1?(k=parseFloat(/^WebGL (\d)/.exec(Z)[1]),T=k>=1):Z.indexOf("OpenGL ES")!==-1&&(k=parseFloat(/^OpenGL ES (\d)/.exec(Z)[1]),T=k>=2);let K=null,pe={};const ce=n.getParameter(n.SCISSOR_BOX),W=n.getParameter(n.VIEWPORT),re=new Ct().fromArray(ce),Ae=new Ct().fromArray(W);function ee(X,ie,Q,le){const Te=new Uint8Array(4),_e=n.createTexture();n.bindTexture(X,_e),n.texParameteri(X,n.TEXTURE_MIN_FILTER,n.NEAREST),n.texParameteri(X,n.TEXTURE_MAG_FILTER,n.NEAREST);for(let qe=0;qe<Q;qe++)X===n.TEXTURE_3D||X===n.TEXTURE_2D_ARRAY?n.texImage3D(ie,0,n.RGBA,1,1,le,0,n.RGBA,n.UNSIGNED_BYTE,Te):n.texImage2D(ie+qe,0,n.RGBA,1,1,0,n.RGBA,n.UNSIGNED_BYTE,Te);return _e}const F={};F[n.TEXTURE_2D]=ee(n.TEXTURE_2D,n.TEXTURE_2D,1),F[n.TEXTURE_CUBE_MAP]=ee(n.TEXTURE_CUBE_MAP,n.TEXTURE_CUBE_MAP_POSITIVE_X,6),F[n.TEXTURE_2D_ARRAY]=ee(n.TEXTURE_2D_ARRAY,n.TEXTURE_2D_ARRAY,1,1),F[n.TEXTURE_3D]=ee(n.TEXTURE_3D,n.TEXTURE_3D,1,1),r.setClear(0,0,0,1),s.setClear(1),o.setClear(0),xe(n.DEPTH_TEST),s.setFunc(Js),ye(!1),ge(bf),xe(n.CULL_FACE),U(An);function xe(X){c[X]!==!0&&(n.enable(X),c[X]=!0)}function G(X){c[X]!==!1&&(n.disable(X),c[X]=!1)}function he(X,ie){return u[X]!==ie?(n.bindFramebuffer(X,ie),u[X]=ie,X===n.DRAW_FRAMEBUFFER&&(u[n.FRAMEBUFFER]=ie),X===n.FRAMEBUFFER&&(u[n.DRAW_FRAMEBUFFER]=ie),!0):!1}function me(X,ie){let Q=f,le=!1;if(X){Q=h.get(ie),Q===void 0&&(Q=[],h.set(ie,Q));const Te=X.textures;if(Q.length!==Te.length||Q[0]!==n.COLOR_ATTACHMENT0){for(let _e=0,qe=Te.length;_e<qe;_e++)Q[_e]=n.COLOR_ATTACHMENT0+_e;Q.length=Te.length,le=!0}}else Q[0]!==n.BACK&&(Q[0]=n.BACK,le=!0);le&&n.drawBuffers(Q)}function fe(X){return d!==X?(n.useProgram(X),d=X,!0):!1}const De={[zr]:n.FUNC_ADD,[Om]:n.FUNC_SUBTRACT,[km]:n.FUNC_REVERSE_SUBTRACT};De[Bm]=n.MIN,De[zm]=n.MAX;const se={[Hm]:n.ZERO,[Gm]:n.ONE,[Vm]:n.SRC_COLOR,[fu]:n.SRC_ALPHA,[Km]:n.SRC_ALPHA_SATURATE,[$m]:n.DST_COLOR,[Xm]:n.DST_ALPHA,[Wm]:n.ONE_MINUS_SRC_COLOR,[du]:n.ONE_MINUS_SRC_ALPHA,[Ym]:n.ONE_MINUS_DST_COLOR,[qm]:n.ONE_MINUS_DST_ALPHA,[jm]:n.CONSTANT_COLOR,[Zm]:n.ONE_MINUS_CONSTANT_COLOR,[Jm]:n.CONSTANT_ALPHA,[Qm]:n.ONE_MINUS_CONSTANT_ALPHA};function U(X,ie,Q,le,Te,_e,qe,rt,Lt,Je){if(X===An){v===!0&&(G(n.BLEND),v=!1);return}if(v===!1&&(xe(n.BLEND),v=!0),X!==Fm){if(X!==g||Je!==P){if((p!==zr||_!==zr)&&(n.blendEquation(n.FUNC_ADD),p=zr,_=zr),Je)switch(X){case Ws:n.blendFuncSeparate(n.ONE,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case Zr:n.blendFunc(n.ONE,n.ONE);break;case wf:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case Ef:n.blendFuncSeparate(n.ZERO,n.SRC_COLOR,n.ZERO,n.SRC_ALPHA);break;default:console.error("THREE.WebGLState: Invalid blending: ",X);break}else switch(X){case Ws:n.blendFuncSeparate(n.SRC_ALPHA,n.ONE_MINUS_SRC_ALPHA,n.ONE,n.ONE_MINUS_SRC_ALPHA);break;case Zr:n.blendFunc(n.SRC_ALPHA,n.ONE);break;case wf:n.blendFuncSeparate(n.ZERO,n.ONE_MINUS_SRC_COLOR,n.ZERO,n.ONE);break;case Ef:n.blendFunc(n.ZERO,n.SRC_COLOR);break;default:console.error("THREE.WebGLState: Invalid blending: ",X);break}m=null,x=null,y=null,C=null,M.set(0,0,0),w=0,g=X,P=Je}return}Te=Te||ie,_e=_e||Q,qe=qe||le,(ie!==p||Te!==_)&&(n.blendEquationSeparate(De[ie],De[Te]),p=ie,_=Te),(Q!==m||le!==x||_e!==y||qe!==C)&&(n.blendFuncSeparate(se[Q],se[le],se[_e],se[qe]),m=Q,x=le,y=_e,C=qe),(rt.equals(M)===!1||Lt!==w)&&(n.blendColor(rt.r,rt.g,rt.b,Lt),M.copy(rt),w=Lt),g=X,P=!1}function Se(X,ie){X.side===Tn?G(n.CULL_FACE):xe(n.CULL_FACE);let Q=X.side===Kt;ie&&(Q=!Q),ye(Q),X.blending===Ws&&X.transparent===!1?U(An):U(X.blending,X.blendEquation,X.blendSrc,X.blendDst,X.blendEquationAlpha,X.blendSrcAlpha,X.blendDstAlpha,X.blendColor,X.blendAlpha,X.premultipliedAlpha),s.setFunc(X.depthFunc),s.setTest(X.depthTest),s.setMask(X.depthWrite),r.setMask(X.colorWrite);const le=X.stencilWrite;o.setTest(le),le&&(o.setMask(X.stencilWriteMask),o.setFunc(X.stencilFunc,X.stencilRef,X.stencilFuncMask),o.setOp(X.stencilFail,X.stencilZFail,X.stencilZPass)),q(X.polygonOffset,X.polygonOffsetFactor,X.polygonOffsetUnits),X.alphaToCoverage===!0?xe(n.SAMPLE_ALPHA_TO_COVERAGE):G(n.SAMPLE_ALPHA_TO_COVERAGE)}function ye(X){I!==X&&(X?n.frontFace(n.CW):n.frontFace(n.CCW),I=X)}function ge(X){X!==Im?(xe(n.CULL_FACE),X!==S&&(X===bf?n.cullFace(n.BACK):X===Um?n.cullFace(n.FRONT):n.cullFace(n.FRONT_AND_BACK))):G(n.CULL_FACE),S=X}function B(X){X!==b&&(T&&n.lineWidth(X),b=X)}function q(X,ie,Q){X?(xe(n.POLYGON_OFFSET_FILL),(N!==ie||R!==Q)&&(n.polygonOffset(ie,Q),N=ie,R=Q)):G(n.POLYGON_OFFSET_FILL)}function V(X){X?xe(n.SCISSOR_TEST):G(n.SCISSOR_TEST)}function A(X){X===void 0&&(X=n.TEXTURE0+H-1),K!==X&&(n.activeTexture(X),K=X)}function E(X,ie,Q){Q===void 0&&(K===null?Q=n.TEXTURE0+H-1:Q=K);let le=pe[Q];le===void 0&&(le={type:void 0,texture:void 0},pe[Q]=le),(le.type!==X||le.texture!==ie)&&(K!==Q&&(n.activeTexture(Q),K=Q),n.bindTexture(X,ie||F[X]),le.type=X,le.texture=ie)}function z(){const X=pe[K];X!==void 0&&X.type!==void 0&&(n.bindTexture(X.type,null),X.type=void 0,X.texture=void 0)}function $(){try{n.compressedTexImage2D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function ne(){try{n.compressedTexImage3D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function te(){try{n.texSubImage2D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function ve(){try{n.texSubImage3D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function ue(){try{n.compressedTexSubImage2D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function Me(){try{n.compressedTexSubImage3D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function Re(){try{n.texStorage2D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function de(){try{n.texStorage3D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function Ee(){try{n.texImage2D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function Ne(){try{n.texImage3D.apply(n,arguments)}catch(X){console.error("THREE.WebGLState:",X)}}function Ve(X){re.equals(X)===!1&&(n.scissor(X.x,X.y,X.z,X.w),re.copy(X))}function Pe(X){Ae.equals(X)===!1&&(n.viewport(X.x,X.y,X.z,X.w),Ae.copy(X))}function Xe(X,ie){let Q=l.get(ie);Q===void 0&&(Q=new WeakMap,l.set(ie,Q));let le=Q.get(X);le===void 0&&(le=n.getUniformBlockIndex(ie,X.name),Q.set(X,le))}function We(X,ie){const le=l.get(ie).get(X);a.get(ie)!==le&&(n.uniformBlockBinding(ie,le,X.__bindingPointIndex),a.set(ie,le))}function dt(){n.disable(n.BLEND),n.disable(n.CULL_FACE),n.disable(n.DEPTH_TEST),n.disable(n.POLYGON_OFFSET_FILL),n.disable(n.SCISSOR_TEST),n.disable(n.STENCIL_TEST),n.disable(n.SAMPLE_ALPHA_TO_COVERAGE),n.blendEquation(n.FUNC_ADD),n.blendFunc(n.ONE,n.ZERO),n.blendFuncSeparate(n.ONE,n.ZERO,n.ONE,n.ZERO),n.blendColor(0,0,0,0),n.colorMask(!0,!0,!0,!0),n.clearColor(0,0,0,0),n.depthMask(!0),n.depthFunc(n.LESS),n.clearDepth(1),n.stencilMask(4294967295),n.stencilFunc(n.ALWAYS,0,4294967295),n.stencilOp(n.KEEP,n.KEEP,n.KEEP),n.clearStencil(0),n.cullFace(n.BACK),n.frontFace(n.CCW),n.polygonOffset(0,0),n.activeTexture(n.TEXTURE0),n.bindFramebuffer(n.FRAMEBUFFER,null),n.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),n.bindFramebuffer(n.READ_FRAMEBUFFER,null),n.useProgram(null),n.lineWidth(1),n.scissor(0,0,n.canvas.width,n.canvas.height),n.viewport(0,0,n.canvas.width,n.canvas.height),c={},K=null,pe={},u={},h=new WeakMap,f=[],d=null,v=!1,g=null,p=null,m=null,x=null,_=null,y=null,C=null,M=new st(0,0,0),w=0,P=!1,I=null,S=null,b=null,N=null,R=null,re.set(0,0,n.canvas.width,n.canvas.height),Ae.set(0,0,n.canvas.width,n.canvas.height),r.reset(),s.reset(),o.reset()}return{buffers:{color:r,depth:s,stencil:o},enable:xe,disable:G,bindFramebuffer:he,drawBuffers:me,useProgram:fe,setBlending:U,setMaterial:Se,setFlipSided:ye,setCullFace:ge,setLineWidth:B,setPolygonOffset:q,setScissorTest:V,activeTexture:A,bindTexture:E,unbindTexture:z,compressedTexImage2D:$,compressedTexImage3D:ne,texImage2D:Ee,texImage3D:Ne,updateUBOMapping:Xe,uniformBlockBinding:We,texStorage2D:Re,texStorage3D:de,texSubImage2D:te,texSubImage3D:ve,compressedTexSubImage2D:ue,compressedTexSubImage3D:Me,scissor:Ve,viewport:Pe,reset:dt}}function gd(n,e,t,i){const r=ky(i);switch(t){case N0:return n*e;case O0:return n*e;case k0:return n*e*2;case B0:return n*e/r.components*r.byteLength;case Ph:return n*e/r.components*r.byteLength;case z0:return n*e*2/r.components*r.byteLength;case Lh:return n*e*2/r.components*r.byteLength;case F0:return n*e*3/r.components*r.byteLength;case Hn:return n*e*4/r.components*r.byteLength;case Dh:return n*e*4/r.components*r.byteLength;case sl:case ol:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*8;case al:case ll:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Eu:case Au:return Math.max(n,16)*Math.max(e,8)/4;case wu:case Tu:return Math.max(n,8)*Math.max(e,8)/2;case Cu:case Ru:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*8;case Pu:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Lu:return Math.floor((n+3)/4)*Math.floor((e+3)/4)*16;case Du:return Math.floor((n+4)/5)*Math.floor((e+3)/4)*16;case Iu:return Math.floor((n+4)/5)*Math.floor((e+4)/5)*16;case Uu:return Math.floor((n+5)/6)*Math.floor((e+4)/5)*16;case Nu:return Math.floor((n+5)/6)*Math.floor((e+5)/6)*16;case Fu:return Math.floor((n+7)/8)*Math.floor((e+4)/5)*16;case Ou:return Math.floor((n+7)/8)*Math.floor((e+5)/6)*16;case ku:return Math.floor((n+7)/8)*Math.floor((e+7)/8)*16;case Bu:return Math.floor((n+9)/10)*Math.floor((e+4)/5)*16;case zu:return Math.floor((n+9)/10)*Math.floor((e+5)/6)*16;case Hu:return Math.floor((n+9)/10)*Math.floor((e+7)/8)*16;case Gu:return Math.floor((n+9)/10)*Math.floor((e+9)/10)*16;case Vu:return Math.floor((n+11)/12)*Math.floor((e+9)/10)*16;case Wu:return Math.floor((n+11)/12)*Math.floor((e+11)/12)*16;case cl:case Xu:case qu:return Math.ceil(n/4)*Math.ceil(e/4)*16;case H0:case $u:return Math.ceil(n/4)*Math.ceil(e/4)*8;case Yu:case Ku:return Math.ceil(n/4)*Math.ceil(e/4)*16}throw new Error(`Unable to determine texture byte length for ${t} format.`)}function ky(n){switch(n){case on:case D0:return{byteLength:1,components:1};case jo:case I0:case ho:return{byteLength:2,components:1};case Ch:case Rh:return{byteLength:2,components:4};case xr:case Ah:case _i:return{byteLength:4,components:1};case U0:return{byteLength:4,components:3}}throw new Error(`Unknown texture type ${n}.`)}function By(n,e,t,i,r,s,o){const a=e.has("WEBGL_multisampled_render_to_texture")?e.get("WEBGL_multisampled_render_to_texture"):null,l=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),c=new we,u=new WeakMap;let h;const f=new WeakMap;let d=!1;try{d=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function v(A,E){return d?new OffscreenCanvas(A,E):wl("canvas")}function g(A,E,z){let $=1;const ne=V(A);if((ne.width>z||ne.height>z)&&($=z/Math.max(ne.width,ne.height)),$<1)if(typeof HTMLImageElement<"u"&&A instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&A instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&A instanceof ImageBitmap||typeof VideoFrame<"u"&&A instanceof VideoFrame){const te=Math.floor($*ne.width),ve=Math.floor($*ne.height);h===void 0&&(h=v(te,ve));const ue=E?v(te,ve):h;return ue.width=te,ue.height=ve,ue.getContext("2d").drawImage(A,0,0,te,ve),console.warn("THREE.WebGLRenderer: Texture has been resized from ("+ne.width+"x"+ne.height+") to ("+te+"x"+ve+")."),ue}else return"data"in A&&console.warn("THREE.WebGLRenderer: Image in DataTexture is too big ("+ne.width+"x"+ne.height+")."),A;return A}function p(A){return A.generateMipmaps&&A.minFilter!==dn&&A.minFilter!==hn}function m(A){n.generateMipmap(A)}function x(A,E,z,$,ne=!1){if(A!==null){if(n[A]!==void 0)return n[A];console.warn("THREE.WebGLRenderer: Attempt to use non-existing WebGL internal format '"+A+"'")}let te=E;if(E===n.RED&&(z===n.FLOAT&&(te=n.R32F),z===n.HALF_FLOAT&&(te=n.R16F),z===n.UNSIGNED_BYTE&&(te=n.R8)),E===n.RED_INTEGER&&(z===n.UNSIGNED_BYTE&&(te=n.R8UI),z===n.UNSIGNED_SHORT&&(te=n.R16UI),z===n.UNSIGNED_INT&&(te=n.R32UI),z===n.BYTE&&(te=n.R8I),z===n.SHORT&&(te=n.R16I),z===n.INT&&(te=n.R32I)),E===n.RG&&(z===n.FLOAT&&(te=n.RG32F),z===n.HALF_FLOAT&&(te=n.RG16F),z===n.UNSIGNED_BYTE&&(te=n.RG8)),E===n.RG_INTEGER&&(z===n.UNSIGNED_BYTE&&(te=n.RG8UI),z===n.UNSIGNED_SHORT&&(te=n.RG16UI),z===n.UNSIGNED_INT&&(te=n.RG32UI),z===n.BYTE&&(te=n.RG8I),z===n.SHORT&&(te=n.RG16I),z===n.INT&&(te=n.RG32I)),E===n.RGB_INTEGER&&(z===n.UNSIGNED_BYTE&&(te=n.RGB8UI),z===n.UNSIGNED_SHORT&&(te=n.RGB16UI),z===n.UNSIGNED_INT&&(te=n.RGB32UI),z===n.BYTE&&(te=n.RGB8I),z===n.SHORT&&(te=n.RGB16I),z===n.INT&&(te=n.RGB32I)),E===n.RGBA_INTEGER&&(z===n.UNSIGNED_BYTE&&(te=n.RGBA8UI),z===n.UNSIGNED_SHORT&&(te=n.RGBA16UI),z===n.UNSIGNED_INT&&(te=n.RGBA32UI),z===n.BYTE&&(te=n.RGBA8I),z===n.SHORT&&(te=n.RGBA16I),z===n.INT&&(te=n.RGBA32I)),E===n.RGB&&z===n.UNSIGNED_INT_5_9_9_9_REV&&(te=n.RGB9_E5),E===n.RGBA){const ve=ne?yl:gt.getTransfer($);z===n.FLOAT&&(te=n.RGBA32F),z===n.HALF_FLOAT&&(te=n.RGBA16F),z===n.UNSIGNED_BYTE&&(te=ve===Pt?n.SRGB8_ALPHA8:n.RGBA8),z===n.UNSIGNED_SHORT_4_4_4_4&&(te=n.RGBA4),z===n.UNSIGNED_SHORT_5_5_5_1&&(te=n.RGB5_A1)}return(te===n.R16F||te===n.R32F||te===n.RG16F||te===n.RG32F||te===n.RGBA16F||te===n.RGBA32F)&&e.get("EXT_color_buffer_float"),te}function _(A,E){let z;return A?E===null||E===xr||E===Jr?z=n.DEPTH24_STENCIL8:E===_i?z=n.DEPTH32F_STENCIL8:E===jo&&(z=n.DEPTH24_STENCIL8,console.warn("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):E===null||E===xr||E===Jr?z=n.DEPTH_COMPONENT24:E===_i?z=n.DEPTH_COMPONENT32F:E===jo&&(z=n.DEPTH_COMPONENT16),z}function y(A,E){return p(A)===!0||A.isFramebufferTexture&&A.minFilter!==dn&&A.minFilter!==hn?Math.log2(Math.max(E.width,E.height))+1:A.mipmaps!==void 0&&A.mipmaps.length>0?A.mipmaps.length:A.isCompressedTexture&&Array.isArray(A.image)?E.mipmaps.length:1}function C(A){const E=A.target;E.removeEventListener("dispose",C),w(E),E.isVideoTexture&&u.delete(E)}function M(A){const E=A.target;E.removeEventListener("dispose",M),I(E)}function w(A){const E=i.get(A);if(E.__webglInit===void 0)return;const z=A.source,$=f.get(z);if($){const ne=$[E.__cacheKey];ne.usedTimes--,ne.usedTimes===0&&P(A),Object.keys($).length===0&&f.delete(z)}i.remove(A)}function P(A){const E=i.get(A);n.deleteTexture(E.__webglTexture);const z=A.source,$=f.get(z);delete $[E.__cacheKey],o.memory.textures--}function I(A){const E=i.get(A);if(A.depthTexture&&A.depthTexture.dispose(),A.isWebGLCubeRenderTarget)for(let $=0;$<6;$++){if(Array.isArray(E.__webglFramebuffer[$]))for(let ne=0;ne<E.__webglFramebuffer[$].length;ne++)n.deleteFramebuffer(E.__webglFramebuffer[$][ne]);else n.deleteFramebuffer(E.__webglFramebuffer[$]);E.__webglDepthbuffer&&n.deleteRenderbuffer(E.__webglDepthbuffer[$])}else{if(Array.isArray(E.__webglFramebuffer))for(let $=0;$<E.__webglFramebuffer.length;$++)n.deleteFramebuffer(E.__webglFramebuffer[$]);else n.deleteFramebuffer(E.__webglFramebuffer);if(E.__webglDepthbuffer&&n.deleteRenderbuffer(E.__webglDepthbuffer),E.__webglMultisampledFramebuffer&&n.deleteFramebuffer(E.__webglMultisampledFramebuffer),E.__webglColorRenderbuffer)for(let $=0;$<E.__webglColorRenderbuffer.length;$++)E.__webglColorRenderbuffer[$]&&n.deleteRenderbuffer(E.__webglColorRenderbuffer[$]);E.__webglDepthRenderbuffer&&n.deleteRenderbuffer(E.__webglDepthRenderbuffer)}const z=A.textures;for(let $=0,ne=z.length;$<ne;$++){const te=i.get(z[$]);te.__webglTexture&&(n.deleteTexture(te.__webglTexture),o.memory.textures--),i.remove(z[$])}i.remove(A)}let S=0;function b(){S=0}function N(){const A=S;return A>=r.maxTextures&&console.warn("THREE.WebGLTextures: Trying to use "+A+" texture units while this GPU supports only "+r.maxTextures),S+=1,A}function R(A){const E=[];return E.push(A.wrapS),E.push(A.wrapT),E.push(A.wrapR||0),E.push(A.magFilter),E.push(A.minFilter),E.push(A.anisotropy),E.push(A.internalFormat),E.push(A.format),E.push(A.type),E.push(A.generateMipmaps),E.push(A.premultiplyAlpha),E.push(A.flipY),E.push(A.unpackAlignment),E.push(A.colorSpace),E.join()}function H(A,E){const z=i.get(A);if(A.isVideoTexture&&B(A),A.isRenderTargetTexture===!1&&A.version>0&&z.__version!==A.version){const $=A.image;if($===null)console.warn("THREE.WebGLRenderer: Texture marked for update but no image data found.");else if($.complete===!1)console.warn("THREE.WebGLRenderer: Texture marked for update but image is incomplete");else{Ae(z,A,E);return}}t.bindTexture(n.TEXTURE_2D,z.__webglTexture,n.TEXTURE0+E)}function T(A,E){const z=i.get(A);if(A.version>0&&z.__version!==A.version){Ae(z,A,E);return}t.bindTexture(n.TEXTURE_2D_ARRAY,z.__webglTexture,n.TEXTURE0+E)}function k(A,E){const z=i.get(A);if(A.version>0&&z.__version!==A.version){Ae(z,A,E);return}t.bindTexture(n.TEXTURE_3D,z.__webglTexture,n.TEXTURE0+E)}function Z(A,E){const z=i.get(A);if(A.version>0&&z.__version!==A.version){ee(z,A,E);return}t.bindTexture(n.TEXTURE_CUBE_MAP,z.__webglTexture,n.TEXTURE0+E)}const K={[xl]:n.REPEAT,[Vr]:n.CLAMP_TO_EDGE,[bu]:n.MIRRORED_REPEAT},pe={[dn]:n.NEAREST,[cg]:n.NEAREST_MIPMAP_NEAREST,[va]:n.NEAREST_MIPMAP_LINEAR,[hn]:n.LINEAR,[ic]:n.LINEAR_MIPMAP_NEAREST,[lr]:n.LINEAR_MIPMAP_LINEAR},ce={[dg]:n.NEVER,[xg]:n.ALWAYS,[pg]:n.LESS,[G0]:n.LEQUAL,[mg]:n.EQUAL,[_g]:n.GEQUAL,[gg]:n.GREATER,[vg]:n.NOTEQUAL};function W(A,E){if(E.type===_i&&e.has("OES_texture_float_linear")===!1&&(E.magFilter===hn||E.magFilter===ic||E.magFilter===va||E.magFilter===lr||E.minFilter===hn||E.minFilter===ic||E.minFilter===va||E.minFilter===lr)&&console.warn("THREE.WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),n.texParameteri(A,n.TEXTURE_WRAP_S,K[E.wrapS]),n.texParameteri(A,n.TEXTURE_WRAP_T,K[E.wrapT]),(A===n.TEXTURE_3D||A===n.TEXTURE_2D_ARRAY)&&n.texParameteri(A,n.TEXTURE_WRAP_R,K[E.wrapR]),n.texParameteri(A,n.TEXTURE_MAG_FILTER,pe[E.magFilter]),n.texParameteri(A,n.TEXTURE_MIN_FILTER,pe[E.minFilter]),E.compareFunction&&(n.texParameteri(A,n.TEXTURE_COMPARE_MODE,n.COMPARE_REF_TO_TEXTURE),n.texParameteri(A,n.TEXTURE_COMPARE_FUNC,ce[E.compareFunction])),e.has("EXT_texture_filter_anisotropic")===!0){if(E.magFilter===dn||E.minFilter!==va&&E.minFilter!==lr||E.type===_i&&e.has("OES_texture_float_linear")===!1)return;if(E.anisotropy>1||i.get(E).__currentAnisotropy){const z=e.get("EXT_texture_filter_anisotropic");n.texParameterf(A,z.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(E.anisotropy,r.getMaxAnisotropy())),i.get(E).__currentAnisotropy=E.anisotropy}}}function re(A,E){let z=!1;A.__webglInit===void 0&&(A.__webglInit=!0,E.addEventListener("dispose",C));const $=E.source;let ne=f.get($);ne===void 0&&(ne={},f.set($,ne));const te=R(E);if(te!==A.__cacheKey){ne[te]===void 0&&(ne[te]={texture:n.createTexture(),usedTimes:0},o.memory.textures++,z=!0),ne[te].usedTimes++;const ve=ne[A.__cacheKey];ve!==void 0&&(ne[A.__cacheKey].usedTimes--,ve.usedTimes===0&&P(E)),A.__cacheKey=te,A.__webglTexture=ne[te].texture}return z}function Ae(A,E,z){let $=n.TEXTURE_2D;(E.isDataArrayTexture||E.isCompressedArrayTexture)&&($=n.TEXTURE_2D_ARRAY),E.isData3DTexture&&($=n.TEXTURE_3D);const ne=re(A,E),te=E.source;t.bindTexture($,A.__webglTexture,n.TEXTURE0+z);const ve=i.get(te);if(te.version!==ve.__version||ne===!0){t.activeTexture(n.TEXTURE0+z);const ue=gt.getPrimaries(gt.workingColorSpace),Me=E.colorSpace===oi?null:gt.getPrimaries(E.colorSpace),Re=E.colorSpace===oi||ue===Me?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,E.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,E.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,E.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,Re);let de=g(E.image,!1,r.maxTextureSize);de=q(E,de);const Ee=s.convert(E.format,E.colorSpace),Ne=s.convert(E.type);let Ve=x(E.internalFormat,Ee,Ne,E.colorSpace,E.isVideoTexture);W($,E);let Pe;const Xe=E.mipmaps,We=E.isVideoTexture!==!0,dt=ve.__version===void 0||ne===!0,X=te.dataReady,ie=y(E,de);if(E.isDepthTexture)Ve=_(E.format===Qr,E.type),dt&&(We?t.texStorage2D(n.TEXTURE_2D,1,Ve,de.width,de.height):t.texImage2D(n.TEXTURE_2D,0,Ve,de.width,de.height,0,Ee,Ne,null));else if(E.isDataTexture)if(Xe.length>0){We&&dt&&t.texStorage2D(n.TEXTURE_2D,ie,Ve,Xe[0].width,Xe[0].height);for(let Q=0,le=Xe.length;Q<le;Q++)Pe=Xe[Q],We?X&&t.texSubImage2D(n.TEXTURE_2D,Q,0,0,Pe.width,Pe.height,Ee,Ne,Pe.data):t.texImage2D(n.TEXTURE_2D,Q,Ve,Pe.width,Pe.height,0,Ee,Ne,Pe.data);E.generateMipmaps=!1}else We?(dt&&t.texStorage2D(n.TEXTURE_2D,ie,Ve,de.width,de.height),X&&t.texSubImage2D(n.TEXTURE_2D,0,0,0,de.width,de.height,Ee,Ne,de.data)):t.texImage2D(n.TEXTURE_2D,0,Ve,de.width,de.height,0,Ee,Ne,de.data);else if(E.isCompressedTexture)if(E.isCompressedArrayTexture){We&&dt&&t.texStorage3D(n.TEXTURE_2D_ARRAY,ie,Ve,Xe[0].width,Xe[0].height,de.depth);for(let Q=0,le=Xe.length;Q<le;Q++)if(Pe=Xe[Q],E.format!==Hn)if(Ee!==null)if(We){if(X)if(E.layerUpdates.size>0){const Te=gd(Pe.width,Pe.height,E.format,E.type);for(const _e of E.layerUpdates){const qe=Pe.data.subarray(_e*Te/Pe.data.BYTES_PER_ELEMENT,(_e+1)*Te/Pe.data.BYTES_PER_ELEMENT);t.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,Q,0,0,_e,Pe.width,Pe.height,1,Ee,qe,0,0)}E.clearLayerUpdates()}else t.compressedTexSubImage3D(n.TEXTURE_2D_ARRAY,Q,0,0,0,Pe.width,Pe.height,de.depth,Ee,Pe.data,0,0)}else t.compressedTexImage3D(n.TEXTURE_2D_ARRAY,Q,Ve,Pe.width,Pe.height,de.depth,0,Pe.data,0,0);else console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else We?X&&t.texSubImage3D(n.TEXTURE_2D_ARRAY,Q,0,0,0,Pe.width,Pe.height,de.depth,Ee,Ne,Pe.data):t.texImage3D(n.TEXTURE_2D_ARRAY,Q,Ve,Pe.width,Pe.height,de.depth,0,Ee,Ne,Pe.data)}else{We&&dt&&t.texStorage2D(n.TEXTURE_2D,ie,Ve,Xe[0].width,Xe[0].height);for(let Q=0,le=Xe.length;Q<le;Q++)Pe=Xe[Q],E.format!==Hn?Ee!==null?We?X&&t.compressedTexSubImage2D(n.TEXTURE_2D,Q,0,0,Pe.width,Pe.height,Ee,Pe.data):t.compressedTexImage2D(n.TEXTURE_2D,Q,Ve,Pe.width,Pe.height,0,Pe.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):We?X&&t.texSubImage2D(n.TEXTURE_2D,Q,0,0,Pe.width,Pe.height,Ee,Ne,Pe.data):t.texImage2D(n.TEXTURE_2D,Q,Ve,Pe.width,Pe.height,0,Ee,Ne,Pe.data)}else if(E.isDataArrayTexture)if(We){if(dt&&t.texStorage3D(n.TEXTURE_2D_ARRAY,ie,Ve,de.width,de.height,de.depth),X)if(E.layerUpdates.size>0){const Q=gd(de.width,de.height,E.format,E.type);for(const le of E.layerUpdates){const Te=de.data.subarray(le*Q/de.data.BYTES_PER_ELEMENT,(le+1)*Q/de.data.BYTES_PER_ELEMENT);t.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,le,de.width,de.height,1,Ee,Ne,Te)}E.clearLayerUpdates()}else t.texSubImage3D(n.TEXTURE_2D_ARRAY,0,0,0,0,de.width,de.height,de.depth,Ee,Ne,de.data)}else t.texImage3D(n.TEXTURE_2D_ARRAY,0,Ve,de.width,de.height,de.depth,0,Ee,Ne,de.data);else if(E.isData3DTexture)We?(dt&&t.texStorage3D(n.TEXTURE_3D,ie,Ve,de.width,de.height,de.depth),X&&t.texSubImage3D(n.TEXTURE_3D,0,0,0,0,de.width,de.height,de.depth,Ee,Ne,de.data)):t.texImage3D(n.TEXTURE_3D,0,Ve,de.width,de.height,de.depth,0,Ee,Ne,de.data);else if(E.isFramebufferTexture){if(dt)if(We)t.texStorage2D(n.TEXTURE_2D,ie,Ve,de.width,de.height);else{let Q=de.width,le=de.height;for(let Te=0;Te<ie;Te++)t.texImage2D(n.TEXTURE_2D,Te,Ve,Q,le,0,Ee,Ne,null),Q>>=1,le>>=1}}else if(Xe.length>0){if(We&&dt){const Q=V(Xe[0]);t.texStorage2D(n.TEXTURE_2D,ie,Ve,Q.width,Q.height)}for(let Q=0,le=Xe.length;Q<le;Q++)Pe=Xe[Q],We?X&&t.texSubImage2D(n.TEXTURE_2D,Q,0,0,Ee,Ne,Pe):t.texImage2D(n.TEXTURE_2D,Q,Ve,Ee,Ne,Pe);E.generateMipmaps=!1}else if(We){if(dt){const Q=V(de);t.texStorage2D(n.TEXTURE_2D,ie,Ve,Q.width,Q.height)}X&&t.texSubImage2D(n.TEXTURE_2D,0,0,0,Ee,Ne,de)}else t.texImage2D(n.TEXTURE_2D,0,Ve,Ee,Ne,de);p(E)&&m($),ve.__version=te.version,E.onUpdate&&E.onUpdate(E)}A.__version=E.version}function ee(A,E,z){if(E.image.length!==6)return;const $=re(A,E),ne=E.source;t.bindTexture(n.TEXTURE_CUBE_MAP,A.__webglTexture,n.TEXTURE0+z);const te=i.get(ne);if(ne.version!==te.__version||$===!0){t.activeTexture(n.TEXTURE0+z);const ve=gt.getPrimaries(gt.workingColorSpace),ue=E.colorSpace===oi?null:gt.getPrimaries(E.colorSpace),Me=E.colorSpace===oi||ve===ue?n.NONE:n.BROWSER_DEFAULT_WEBGL;n.pixelStorei(n.UNPACK_FLIP_Y_WEBGL,E.flipY),n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,E.premultiplyAlpha),n.pixelStorei(n.UNPACK_ALIGNMENT,E.unpackAlignment),n.pixelStorei(n.UNPACK_COLORSPACE_CONVERSION_WEBGL,Me);const Re=E.isCompressedTexture||E.image[0].isCompressedTexture,de=E.image[0]&&E.image[0].isDataTexture,Ee=[];for(let le=0;le<6;le++)!Re&&!de?Ee[le]=g(E.image[le],!0,r.maxCubemapSize):Ee[le]=de?E.image[le].image:E.image[le],Ee[le]=q(E,Ee[le]);const Ne=Ee[0],Ve=s.convert(E.format,E.colorSpace),Pe=s.convert(E.type),Xe=x(E.internalFormat,Ve,Pe,E.colorSpace),We=E.isVideoTexture!==!0,dt=te.__version===void 0||$===!0,X=ne.dataReady;let ie=y(E,Ne);W(n.TEXTURE_CUBE_MAP,E);let Q;if(Re){We&&dt&&t.texStorage2D(n.TEXTURE_CUBE_MAP,ie,Xe,Ne.width,Ne.height);for(let le=0;le<6;le++){Q=Ee[le].mipmaps;for(let Te=0;Te<Q.length;Te++){const _e=Q[Te];E.format!==Hn?Ve!==null?We?X&&t.compressedTexSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te,0,0,_e.width,_e.height,Ve,_e.data):t.compressedTexImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te,Xe,_e.width,_e.height,0,_e.data):console.warn("THREE.WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):We?X&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te,0,0,_e.width,_e.height,Ve,Pe,_e.data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te,Xe,_e.width,_e.height,0,Ve,Pe,_e.data)}}}else{if(Q=E.mipmaps,We&&dt){Q.length>0&&ie++;const le=V(Ee[0]);t.texStorage2D(n.TEXTURE_CUBE_MAP,ie,Xe,le.width,le.height)}for(let le=0;le<6;le++)if(de){We?X&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,0,0,0,Ee[le].width,Ee[le].height,Ve,Pe,Ee[le].data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,0,Xe,Ee[le].width,Ee[le].height,0,Ve,Pe,Ee[le].data);for(let Te=0;Te<Q.length;Te++){const qe=Q[Te].image[le].image;We?X&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te+1,0,0,qe.width,qe.height,Ve,Pe,qe.data):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te+1,Xe,qe.width,qe.height,0,Ve,Pe,qe.data)}}else{We?X&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,0,0,0,Ve,Pe,Ee[le]):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,0,Xe,Ve,Pe,Ee[le]);for(let Te=0;Te<Q.length;Te++){const _e=Q[Te];We?X&&t.texSubImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te+1,0,0,Ve,Pe,_e.image[le]):t.texImage2D(n.TEXTURE_CUBE_MAP_POSITIVE_X+le,Te+1,Xe,Ve,Pe,_e.image[le])}}}p(E)&&m(n.TEXTURE_CUBE_MAP),te.__version=ne.version,E.onUpdate&&E.onUpdate(E)}A.__version=E.version}function F(A,E,z,$,ne,te){const ve=s.convert(z.format,z.colorSpace),ue=s.convert(z.type),Me=x(z.internalFormat,ve,ue,z.colorSpace);if(!i.get(E).__hasExternalTextures){const de=Math.max(1,E.width>>te),Ee=Math.max(1,E.height>>te);ne===n.TEXTURE_3D||ne===n.TEXTURE_2D_ARRAY?t.texImage3D(ne,te,Me,de,Ee,E.depth,0,ve,ue,null):t.texImage2D(ne,te,Me,de,Ee,0,ve,ue,null)}t.bindFramebuffer(n.FRAMEBUFFER,A),ge(E)?a.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,$,ne,i.get(z).__webglTexture,0,ye(E)):(ne===n.TEXTURE_2D||ne>=n.TEXTURE_CUBE_MAP_POSITIVE_X&&ne<=n.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&n.framebufferTexture2D(n.FRAMEBUFFER,$,ne,i.get(z).__webglTexture,te),t.bindFramebuffer(n.FRAMEBUFFER,null)}function xe(A,E,z){if(n.bindRenderbuffer(n.RENDERBUFFER,A),E.depthBuffer){const $=E.depthTexture,ne=$&&$.isDepthTexture?$.type:null,te=_(E.stencilBuffer,ne),ve=E.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,ue=ye(E);ge(E)?a.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,ue,te,E.width,E.height):z?n.renderbufferStorageMultisample(n.RENDERBUFFER,ue,te,E.width,E.height):n.renderbufferStorage(n.RENDERBUFFER,te,E.width,E.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,ve,n.RENDERBUFFER,A)}else{const $=E.textures;for(let ne=0;ne<$.length;ne++){const te=$[ne],ve=s.convert(te.format,te.colorSpace),ue=s.convert(te.type),Me=x(te.internalFormat,ve,ue,te.colorSpace),Re=ye(E);z&&ge(E)===!1?n.renderbufferStorageMultisample(n.RENDERBUFFER,Re,Me,E.width,E.height):ge(E)?a.renderbufferStorageMultisampleEXT(n.RENDERBUFFER,Re,Me,E.width,E.height):n.renderbufferStorage(n.RENDERBUFFER,Me,E.width,E.height)}}n.bindRenderbuffer(n.RENDERBUFFER,null)}function G(A,E){if(E&&E.isWebGLCubeRenderTarget)throw new Error("Depth Texture with cube render targets is not supported");if(t.bindFramebuffer(n.FRAMEBUFFER,A),!(E.depthTexture&&E.depthTexture.isDepthTexture))throw new Error("renderTarget.depthTexture must be an instance of THREE.DepthTexture");(!i.get(E.depthTexture).__webglTexture||E.depthTexture.image.width!==E.width||E.depthTexture.image.height!==E.height)&&(E.depthTexture.image.width=E.width,E.depthTexture.image.height=E.height,E.depthTexture.needsUpdate=!0),H(E.depthTexture,0);const $=i.get(E.depthTexture).__webglTexture,ne=ye(E);if(E.depthTexture.format===Xs)ge(E)?a.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,$,0,ne):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_ATTACHMENT,n.TEXTURE_2D,$,0);else if(E.depthTexture.format===Qr)ge(E)?a.framebufferTexture2DMultisampleEXT(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,$,0,ne):n.framebufferTexture2D(n.FRAMEBUFFER,n.DEPTH_STENCIL_ATTACHMENT,n.TEXTURE_2D,$,0);else throw new Error("Unknown depthTexture format")}function he(A){const E=i.get(A),z=A.isWebGLCubeRenderTarget===!0;if(E.__boundDepthTexture!==A.depthTexture){const $=A.depthTexture;if(E.__depthDisposeCallback&&E.__depthDisposeCallback(),$){const ne=()=>{delete E.__boundDepthTexture,delete E.__depthDisposeCallback,$.removeEventListener("dispose",ne)};$.addEventListener("dispose",ne),E.__depthDisposeCallback=ne}E.__boundDepthTexture=$}if(A.depthTexture&&!E.__autoAllocateDepthBuffer){if(z)throw new Error("target.depthTexture not supported in Cube render targets");G(E.__webglFramebuffer,A)}else if(z){E.__webglDepthbuffer=[];for(let $=0;$<6;$++)if(t.bindFramebuffer(n.FRAMEBUFFER,E.__webglFramebuffer[$]),E.__webglDepthbuffer[$]===void 0)E.__webglDepthbuffer[$]=n.createRenderbuffer(),xe(E.__webglDepthbuffer[$],A,!1);else{const ne=A.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,te=E.__webglDepthbuffer[$];n.bindRenderbuffer(n.RENDERBUFFER,te),n.framebufferRenderbuffer(n.FRAMEBUFFER,ne,n.RENDERBUFFER,te)}}else if(t.bindFramebuffer(n.FRAMEBUFFER,E.__webglFramebuffer),E.__webglDepthbuffer===void 0)E.__webglDepthbuffer=n.createRenderbuffer(),xe(E.__webglDepthbuffer,A,!1);else{const $=A.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,ne=E.__webglDepthbuffer;n.bindRenderbuffer(n.RENDERBUFFER,ne),n.framebufferRenderbuffer(n.FRAMEBUFFER,$,n.RENDERBUFFER,ne)}t.bindFramebuffer(n.FRAMEBUFFER,null)}function me(A,E,z){const $=i.get(A);E!==void 0&&F($.__webglFramebuffer,A,A.texture,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,0),z!==void 0&&he(A)}function fe(A){const E=A.texture,z=i.get(A),$=i.get(E);A.addEventListener("dispose",M);const ne=A.textures,te=A.isWebGLCubeRenderTarget===!0,ve=ne.length>1;if(ve||($.__webglTexture===void 0&&($.__webglTexture=n.createTexture()),$.__version=E.version,o.memory.textures++),te){z.__webglFramebuffer=[];for(let ue=0;ue<6;ue++)if(E.mipmaps&&E.mipmaps.length>0){z.__webglFramebuffer[ue]=[];for(let Me=0;Me<E.mipmaps.length;Me++)z.__webglFramebuffer[ue][Me]=n.createFramebuffer()}else z.__webglFramebuffer[ue]=n.createFramebuffer()}else{if(E.mipmaps&&E.mipmaps.length>0){z.__webglFramebuffer=[];for(let ue=0;ue<E.mipmaps.length;ue++)z.__webglFramebuffer[ue]=n.createFramebuffer()}else z.__webglFramebuffer=n.createFramebuffer();if(ve)for(let ue=0,Me=ne.length;ue<Me;ue++){const Re=i.get(ne[ue]);Re.__webglTexture===void 0&&(Re.__webglTexture=n.createTexture(),o.memory.textures++)}if(A.samples>0&&ge(A)===!1){z.__webglMultisampledFramebuffer=n.createFramebuffer(),z.__webglColorRenderbuffer=[],t.bindFramebuffer(n.FRAMEBUFFER,z.__webglMultisampledFramebuffer);for(let ue=0;ue<ne.length;ue++){const Me=ne[ue];z.__webglColorRenderbuffer[ue]=n.createRenderbuffer(),n.bindRenderbuffer(n.RENDERBUFFER,z.__webglColorRenderbuffer[ue]);const Re=s.convert(Me.format,Me.colorSpace),de=s.convert(Me.type),Ee=x(Me.internalFormat,Re,de,Me.colorSpace,A.isXRRenderTarget===!0),Ne=ye(A);n.renderbufferStorageMultisample(n.RENDERBUFFER,Ne,Ee,A.width,A.height),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+ue,n.RENDERBUFFER,z.__webglColorRenderbuffer[ue])}n.bindRenderbuffer(n.RENDERBUFFER,null),A.depthBuffer&&(z.__webglDepthRenderbuffer=n.createRenderbuffer(),xe(z.__webglDepthRenderbuffer,A,!0)),t.bindFramebuffer(n.FRAMEBUFFER,null)}}if(te){t.bindTexture(n.TEXTURE_CUBE_MAP,$.__webglTexture),W(n.TEXTURE_CUBE_MAP,E);for(let ue=0;ue<6;ue++)if(E.mipmaps&&E.mipmaps.length>0)for(let Me=0;Me<E.mipmaps.length;Me++)F(z.__webglFramebuffer[ue][Me],A,E,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+ue,Me);else F(z.__webglFramebuffer[ue],A,E,n.COLOR_ATTACHMENT0,n.TEXTURE_CUBE_MAP_POSITIVE_X+ue,0);p(E)&&m(n.TEXTURE_CUBE_MAP),t.unbindTexture()}else if(ve){for(let ue=0,Me=ne.length;ue<Me;ue++){const Re=ne[ue],de=i.get(Re);t.bindTexture(n.TEXTURE_2D,de.__webglTexture),W(n.TEXTURE_2D,Re),F(z.__webglFramebuffer,A,Re,n.COLOR_ATTACHMENT0+ue,n.TEXTURE_2D,0),p(Re)&&m(n.TEXTURE_2D)}t.unbindTexture()}else{let ue=n.TEXTURE_2D;if((A.isWebGL3DRenderTarget||A.isWebGLArrayRenderTarget)&&(ue=A.isWebGL3DRenderTarget?n.TEXTURE_3D:n.TEXTURE_2D_ARRAY),t.bindTexture(ue,$.__webglTexture),W(ue,E),E.mipmaps&&E.mipmaps.length>0)for(let Me=0;Me<E.mipmaps.length;Me++)F(z.__webglFramebuffer[Me],A,E,n.COLOR_ATTACHMENT0,ue,Me);else F(z.__webglFramebuffer,A,E,n.COLOR_ATTACHMENT0,ue,0);p(E)&&m(ue),t.unbindTexture()}A.depthBuffer&&he(A)}function De(A){const E=A.textures;for(let z=0,$=E.length;z<$;z++){const ne=E[z];if(p(ne)){const te=A.isWebGLCubeRenderTarget?n.TEXTURE_CUBE_MAP:n.TEXTURE_2D,ve=i.get(ne).__webglTexture;t.bindTexture(te,ve),m(te),t.unbindTexture()}}}const se=[],U=[];function Se(A){if(A.samples>0){if(ge(A)===!1){const E=A.textures,z=A.width,$=A.height;let ne=n.COLOR_BUFFER_BIT;const te=A.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT,ve=i.get(A),ue=E.length>1;if(ue)for(let Me=0;Me<E.length;Me++)t.bindFramebuffer(n.FRAMEBUFFER,ve.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Me,n.RENDERBUFFER,null),t.bindFramebuffer(n.FRAMEBUFFER,ve.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+Me,n.TEXTURE_2D,null,0);t.bindFramebuffer(n.READ_FRAMEBUFFER,ve.__webglMultisampledFramebuffer),t.bindFramebuffer(n.DRAW_FRAMEBUFFER,ve.__webglFramebuffer);for(let Me=0;Me<E.length;Me++){if(A.resolveDepthBuffer&&(A.depthBuffer&&(ne|=n.DEPTH_BUFFER_BIT),A.stencilBuffer&&A.resolveStencilBuffer&&(ne|=n.STENCIL_BUFFER_BIT)),ue){n.framebufferRenderbuffer(n.READ_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.RENDERBUFFER,ve.__webglColorRenderbuffer[Me]);const Re=i.get(E[Me]).__webglTexture;n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,Re,0)}n.blitFramebuffer(0,0,z,$,0,0,z,$,ne,n.NEAREST),l===!0&&(se.length=0,U.length=0,se.push(n.COLOR_ATTACHMENT0+Me),A.depthBuffer&&A.resolveDepthBuffer===!1&&(se.push(te),U.push(te),n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,U)),n.invalidateFramebuffer(n.READ_FRAMEBUFFER,se))}if(t.bindFramebuffer(n.READ_FRAMEBUFFER,null),t.bindFramebuffer(n.DRAW_FRAMEBUFFER,null),ue)for(let Me=0;Me<E.length;Me++){t.bindFramebuffer(n.FRAMEBUFFER,ve.__webglMultisampledFramebuffer),n.framebufferRenderbuffer(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0+Me,n.RENDERBUFFER,ve.__webglColorRenderbuffer[Me]);const Re=i.get(E[Me]).__webglTexture;t.bindFramebuffer(n.FRAMEBUFFER,ve.__webglFramebuffer),n.framebufferTexture2D(n.DRAW_FRAMEBUFFER,n.COLOR_ATTACHMENT0+Me,n.TEXTURE_2D,Re,0)}t.bindFramebuffer(n.DRAW_FRAMEBUFFER,ve.__webglMultisampledFramebuffer)}else if(A.depthBuffer&&A.resolveDepthBuffer===!1&&l){const E=A.stencilBuffer?n.DEPTH_STENCIL_ATTACHMENT:n.DEPTH_ATTACHMENT;n.invalidateFramebuffer(n.DRAW_FRAMEBUFFER,[E])}}}function ye(A){return Math.min(r.maxSamples,A.samples)}function ge(A){const E=i.get(A);return A.samples>0&&e.has("WEBGL_multisampled_render_to_texture")===!0&&E.__useRenderToTexture!==!1}function B(A){const E=o.render.frame;u.get(A)!==E&&(u.set(A,E),A.update())}function q(A,E){const z=A.colorSpace,$=A.format,ne=A.type;return A.isCompressedTexture===!0||A.isVideoTexture===!0||z!==wi&&z!==oi&&(gt.getTransfer(z)===Pt?($!==Hn||ne!==on)&&console.warn("THREE.WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):console.error("THREE.WebGLTextures: Unsupported texture color space:",z)),E}function V(A){return typeof HTMLImageElement<"u"&&A instanceof HTMLImageElement?(c.width=A.naturalWidth||A.width,c.height=A.naturalHeight||A.height):typeof VideoFrame<"u"&&A instanceof VideoFrame?(c.width=A.displayWidth,c.height=A.displayHeight):(c.width=A.width,c.height=A.height),c}this.allocateTextureUnit=N,this.resetTextureUnits=b,this.setTexture2D=H,this.setTexture2DArray=T,this.setTexture3D=k,this.setTextureCube=Z,this.rebindTextures=me,this.setupRenderTarget=fe,this.updateRenderTargetMipmap=De,this.updateMultisampleRenderTarget=Se,this.setupDepthRenderbuffer=he,this.setupFrameBufferTexture=F,this.useMultisampledRTT=ge}function zy(n,e){function t(i,r=oi){let s;const o=gt.getTransfer(r);if(i===on)return n.UNSIGNED_BYTE;if(i===Ch)return n.UNSIGNED_SHORT_4_4_4_4;if(i===Rh)return n.UNSIGNED_SHORT_5_5_5_1;if(i===U0)return n.UNSIGNED_INT_5_9_9_9_REV;if(i===D0)return n.BYTE;if(i===I0)return n.SHORT;if(i===jo)return n.UNSIGNED_SHORT;if(i===Ah)return n.INT;if(i===xr)return n.UNSIGNED_INT;if(i===_i)return n.FLOAT;if(i===ho)return n.HALF_FLOAT;if(i===N0)return n.ALPHA;if(i===F0)return n.RGB;if(i===Hn)return n.RGBA;if(i===O0)return n.LUMINANCE;if(i===k0)return n.LUMINANCE_ALPHA;if(i===Xs)return n.DEPTH_COMPONENT;if(i===Qr)return n.DEPTH_STENCIL;if(i===B0)return n.RED;if(i===Ph)return n.RED_INTEGER;if(i===z0)return n.RG;if(i===Lh)return n.RG_INTEGER;if(i===Dh)return n.RGBA_INTEGER;if(i===sl||i===ol||i===al||i===ll)if(o===Pt)if(s=e.get("WEBGL_compressed_texture_s3tc_srgb"),s!==null){if(i===sl)return s.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(i===ol)return s.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(i===al)return s.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(i===ll)return s.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(s=e.get("WEBGL_compressed_texture_s3tc"),s!==null){if(i===sl)return s.COMPRESSED_RGB_S3TC_DXT1_EXT;if(i===ol)return s.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(i===al)return s.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(i===ll)return s.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(i===wu||i===Eu||i===Tu||i===Au)if(s=e.get("WEBGL_compressed_texture_pvrtc"),s!==null){if(i===wu)return s.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(i===Eu)return s.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(i===Tu)return s.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(i===Au)return s.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(i===Cu||i===Ru||i===Pu)if(s=e.get("WEBGL_compressed_texture_etc"),s!==null){if(i===Cu||i===Ru)return o===Pt?s.COMPRESSED_SRGB8_ETC2:s.COMPRESSED_RGB8_ETC2;if(i===Pu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:s.COMPRESSED_RGBA8_ETC2_EAC}else return null;if(i===Lu||i===Du||i===Iu||i===Uu||i===Nu||i===Fu||i===Ou||i===ku||i===Bu||i===zu||i===Hu||i===Gu||i===Vu||i===Wu)if(s=e.get("WEBGL_compressed_texture_astc"),s!==null){if(i===Lu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:s.COMPRESSED_RGBA_ASTC_4x4_KHR;if(i===Du)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:s.COMPRESSED_RGBA_ASTC_5x4_KHR;if(i===Iu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:s.COMPRESSED_RGBA_ASTC_5x5_KHR;if(i===Uu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:s.COMPRESSED_RGBA_ASTC_6x5_KHR;if(i===Nu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:s.COMPRESSED_RGBA_ASTC_6x6_KHR;if(i===Fu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:s.COMPRESSED_RGBA_ASTC_8x5_KHR;if(i===Ou)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:s.COMPRESSED_RGBA_ASTC_8x6_KHR;if(i===ku)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:s.COMPRESSED_RGBA_ASTC_8x8_KHR;if(i===Bu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:s.COMPRESSED_RGBA_ASTC_10x5_KHR;if(i===zu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:s.COMPRESSED_RGBA_ASTC_10x6_KHR;if(i===Hu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:s.COMPRESSED_RGBA_ASTC_10x8_KHR;if(i===Gu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:s.COMPRESSED_RGBA_ASTC_10x10_KHR;if(i===Vu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:s.COMPRESSED_RGBA_ASTC_12x10_KHR;if(i===Wu)return o===Pt?s.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:s.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(i===cl||i===Xu||i===qu)if(s=e.get("EXT_texture_compression_bptc"),s!==null){if(i===cl)return o===Pt?s.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:s.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(i===Xu)return s.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(i===qu)return s.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(i===H0||i===$u||i===Yu||i===Ku)if(s=e.get("EXT_texture_compression_rgtc"),s!==null){if(i===cl)return s.COMPRESSED_RED_RGTC1_EXT;if(i===$u)return s.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(i===Yu)return s.COMPRESSED_RED_GREEN_RGTC2_EXT;if(i===Ku)return s.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return i===Jr?n.UNSIGNED_INT_24_8:n[i]!==void 0?n[i]:null}return{convert:t}}class Hy extends kn{constructor(e=[]){super(),this.isArrayCamera=!0,this.cameras=e}}class Zn extends yn{constructor(){super(),this.isGroup=!0,this.type="Group"}}const Gy={type:"move"};class Lc{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new Zn,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new Zn,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new O,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new O),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new Zn,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new O,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new O),this._grip}dispatchEvent(e){return this._targetRay!==null&&this._targetRay.dispatchEvent(e),this._grip!==null&&this._grip.dispatchEvent(e),this._hand!==null&&this._hand.dispatchEvent(e),this}connect(e){if(e&&e.hand){const t=this._hand;if(t)for(const i of e.hand.values())this._getHandJoint(t,i)}return this.dispatchEvent({type:"connected",data:e}),this}disconnect(e){return this.dispatchEvent({type:"disconnected",data:e}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(e,t,i){let r=null,s=null,o=null;const a=this._targetRay,l=this._grip,c=this._hand;if(e&&t.session.visibilityState!=="visible-blurred"){if(c&&e.hand){o=!0;for(const g of e.hand.values()){const p=t.getJointPose(g,i),m=this._getHandJoint(c,g);p!==null&&(m.matrix.fromArray(p.transform.matrix),m.matrix.decompose(m.position,m.rotation,m.scale),m.matrixWorldNeedsUpdate=!0,m.jointRadius=p.radius),m.visible=p!==null}const u=c.joints["index-finger-tip"],h=c.joints["thumb-tip"],f=u.position.distanceTo(h.position),d=.02,v=.005;c.inputState.pinching&&f>d+v?(c.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:e.handedness,target:this})):!c.inputState.pinching&&f<=d-v&&(c.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:e.handedness,target:this}))}else l!==null&&e.gripSpace&&(s=t.getPose(e.gripSpace,i),s!==null&&(l.matrix.fromArray(s.transform.matrix),l.matrix.decompose(l.position,l.rotation,l.scale),l.matrixWorldNeedsUpdate=!0,s.linearVelocity?(l.hasLinearVelocity=!0,l.linearVelocity.copy(s.linearVelocity)):l.hasLinearVelocity=!1,s.angularVelocity?(l.hasAngularVelocity=!0,l.angularVelocity.copy(s.angularVelocity)):l.hasAngularVelocity=!1));a!==null&&(r=t.getPose(e.targetRaySpace,i),r===null&&s!==null&&(r=s),r!==null&&(a.matrix.fromArray(r.transform.matrix),a.matrix.decompose(a.position,a.rotation,a.scale),a.matrixWorldNeedsUpdate=!0,r.linearVelocity?(a.hasLinearVelocity=!0,a.linearVelocity.copy(r.linearVelocity)):a.hasLinearVelocity=!1,r.angularVelocity?(a.hasAngularVelocity=!0,a.angularVelocity.copy(r.angularVelocity)):a.hasAngularVelocity=!1,this.dispatchEvent(Gy)))}return a!==null&&(a.visible=r!==null),l!==null&&(l.visible=s!==null),c!==null&&(c.visible=o!==null),this}_getHandJoint(e,t){if(e.joints[t.jointName]===void 0){const i=new Zn;i.matrixAutoUpdate=!1,i.visible=!1,e.joints[t.jointName]=i,e.add(i)}return e.joints[t.jointName]}}const Vy=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,Wy=`
uniform sampler2DArray depthColor;
uniform float depthWidth;
uniform float depthHeight;

void main() {

	vec2 coord = vec2( gl_FragCoord.x / depthWidth, gl_FragCoord.y / depthHeight );

	if ( coord.x >= 1.0 ) {

		gl_FragDepth = texture( depthColor, vec3( coord.x - 1.0, coord.y, 1 ) ).r;

	} else {

		gl_FragDepth = texture( depthColor, vec3( coord.x, coord.y, 0 ) ).r;

	}

}`;class Xy{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(e,t,i){if(this.texture===null){const r=new sn,s=e.properties.get(r);s.__webglTexture=t.texture,(t.depthNear!=i.depthNear||t.depthFar!=i.depthFar)&&(this.depthNear=t.depthNear,this.depthFar=t.depthFar),this.texture=r}}getMesh(e){if(this.texture!==null&&this.mesh===null){const t=e.cameras[0].viewport,i=new xt({vertexShader:Vy,fragmentShader:Wy,uniforms:{depthColor:{value:this.texture},depthWidth:{value:t.z},depthHeight:{value:t.w}}});this.mesh=new Gt(new as(20,20),i)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}}class qy extends Wi{constructor(e,t){super();const i=this;let r=null,s=1,o=null,a="local-floor",l=1,c=null,u=null,h=null,f=null,d=null,v=null;const g=new Xy,p=t.getContextAttributes();let m=null,x=null;const _=[],y=[],C=new we;let M=null;const w=new kn;w.layers.enable(1),w.viewport=new Ct;const P=new kn;P.layers.enable(2),P.viewport=new Ct;const I=[w,P],S=new Hy;S.layers.enable(1),S.layers.enable(2);let b=null,N=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(ee){let F=_[ee];return F===void 0&&(F=new Lc,_[ee]=F),F.getTargetRaySpace()},this.getControllerGrip=function(ee){let F=_[ee];return F===void 0&&(F=new Lc,_[ee]=F),F.getGripSpace()},this.getHand=function(ee){let F=_[ee];return F===void 0&&(F=new Lc,_[ee]=F),F.getHandSpace()};function R(ee){const F=y.indexOf(ee.inputSource);if(F===-1)return;const xe=_[F];xe!==void 0&&(xe.update(ee.inputSource,ee.frame,c||o),xe.dispatchEvent({type:ee.type,data:ee.inputSource}))}function H(){r.removeEventListener("select",R),r.removeEventListener("selectstart",R),r.removeEventListener("selectend",R),r.removeEventListener("squeeze",R),r.removeEventListener("squeezestart",R),r.removeEventListener("squeezeend",R),r.removeEventListener("end",H),r.removeEventListener("inputsourceschange",T);for(let ee=0;ee<_.length;ee++){const F=y[ee];F!==null&&(y[ee]=null,_[ee].disconnect(F))}b=null,N=null,g.reset(),e.setRenderTarget(m),d=null,f=null,h=null,r=null,x=null,Ae.stop(),i.isPresenting=!1,e.setPixelRatio(M),e.setSize(C.width,C.height,!1),i.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(ee){s=ee,i.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(ee){a=ee,i.isPresenting===!0&&console.warn("THREE.WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return c||o},this.setReferenceSpace=function(ee){c=ee},this.getBaseLayer=function(){return f!==null?f:d},this.getBinding=function(){return h},this.getFrame=function(){return v},this.getSession=function(){return r},this.setSession=async function(ee){if(r=ee,r!==null){if(m=e.getRenderTarget(),r.addEventListener("select",R),r.addEventListener("selectstart",R),r.addEventListener("selectend",R),r.addEventListener("squeeze",R),r.addEventListener("squeezestart",R),r.addEventListener("squeezeend",R),r.addEventListener("end",H),r.addEventListener("inputsourceschange",T),p.xrCompatible!==!0&&await t.makeXRCompatible(),M=e.getPixelRatio(),e.getSize(C),r.renderState.layers===void 0){const F={antialias:p.antialias,alpha:!0,depth:p.depth,stencil:p.stencil,framebufferScaleFactor:s};d=new XRWebGLLayer(r,t,F),r.updateRenderState({baseLayer:d}),e.setPixelRatio(1),e.setSize(d.framebufferWidth,d.framebufferHeight,!1),x=new Sn(d.framebufferWidth,d.framebufferHeight,{format:Hn,type:on,colorSpace:e.outputColorSpace,stencilBuffer:p.stencil})}else{let F=null,xe=null,G=null;p.depth&&(G=p.stencil?t.DEPTH24_STENCIL8:t.DEPTH_COMPONENT24,F=p.stencil?Qr:Xs,xe=p.stencil?Jr:xr);const he={colorFormat:t.RGBA8,depthFormat:G,scaleFactor:s};h=new XRWebGLBinding(r,t),f=h.createProjectionLayer(he),r.updateRenderState({layers:[f]}),e.setPixelRatio(1),e.setSize(f.textureWidth,f.textureHeight,!1),x=new Sn(f.textureWidth,f.textureHeight,{format:Hn,type:on,depthTexture:new Oh(f.textureWidth,f.textureHeight,xe,void 0,void 0,void 0,void 0,void 0,void 0,F),stencilBuffer:p.stencil,colorSpace:e.outputColorSpace,samples:p.antialias?4:0,resolveDepthBuffer:f.ignoreDepthValues===!1})}x.isXRRenderTarget=!0,this.setFoveation(l),c=null,o=await r.requestReferenceSpace(a),Ae.setContext(r),Ae.start(),i.isPresenting=!0,i.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(r!==null)return r.environmentBlendMode},this.getDepthTexture=function(){return g.getDepthTexture()};function T(ee){for(let F=0;F<ee.removed.length;F++){const xe=ee.removed[F],G=y.indexOf(xe);G>=0&&(y[G]=null,_[G].disconnect(xe))}for(let F=0;F<ee.added.length;F++){const xe=ee.added[F];let G=y.indexOf(xe);if(G===-1){for(let me=0;me<_.length;me++)if(me>=y.length){y.push(xe),G=me;break}else if(y[me]===null){y[me]=xe,G=me;break}if(G===-1)break}const he=_[G];he&&he.connect(xe)}}const k=new O,Z=new O;function K(ee,F,xe){k.setFromMatrixPosition(F.matrixWorld),Z.setFromMatrixPosition(xe.matrixWorld);const G=k.distanceTo(Z),he=F.projectionMatrix.elements,me=xe.projectionMatrix.elements,fe=he[14]/(he[10]-1),De=he[14]/(he[10]+1),se=(he[9]+1)/he[5],U=(he[9]-1)/he[5],Se=(he[8]-1)/he[0],ye=(me[8]+1)/me[0],ge=fe*Se,B=fe*ye,q=G/(-Se+ye),V=q*-Se;if(F.matrixWorld.decompose(ee.position,ee.quaternion,ee.scale),ee.translateX(V),ee.translateZ(q),ee.matrixWorld.compose(ee.position,ee.quaternion,ee.scale),ee.matrixWorldInverse.copy(ee.matrixWorld).invert(),he[10]===-1)ee.projectionMatrix.copy(F.projectionMatrix),ee.projectionMatrixInverse.copy(F.projectionMatrixInverse);else{const A=fe+q,E=De+q,z=ge-V,$=B+(G-V),ne=se*De/E*A,te=U*De/E*A;ee.projectionMatrix.makePerspective(z,$,ne,te,A,E),ee.projectionMatrixInverse.copy(ee.projectionMatrix).invert()}}function pe(ee,F){F===null?ee.matrixWorld.copy(ee.matrix):ee.matrixWorld.multiplyMatrices(F.matrixWorld,ee.matrix),ee.matrixWorldInverse.copy(ee.matrixWorld).invert()}this.updateCamera=function(ee){if(r===null)return;let F=ee.near,xe=ee.far;g.texture!==null&&(g.depthNear>0&&(F=g.depthNear),g.depthFar>0&&(xe=g.depthFar)),S.near=P.near=w.near=F,S.far=P.far=w.far=xe,(b!==S.near||N!==S.far)&&(r.updateRenderState({depthNear:S.near,depthFar:S.far}),b=S.near,N=S.far);const G=ee.parent,he=S.cameras;pe(S,G);for(let me=0;me<he.length;me++)pe(he[me],G);he.length===2?K(S,w,P):S.projectionMatrix.copy(w.projectionMatrix),ce(ee,S,G)};function ce(ee,F,xe){xe===null?ee.matrix.copy(F.matrixWorld):(ee.matrix.copy(xe.matrixWorld),ee.matrix.invert(),ee.matrix.multiply(F.matrixWorld)),ee.matrix.decompose(ee.position,ee.quaternion,ee.scale),ee.updateMatrixWorld(!0),ee.projectionMatrix.copy(F.projectionMatrix),ee.projectionMatrixInverse.copy(F.projectionMatrixInverse),ee.isPerspectiveCamera&&(ee.fov=Zo*2*Math.atan(1/ee.projectionMatrix.elements[5]),ee.zoom=1)}this.getCamera=function(){return S},this.getFoveation=function(){if(!(f===null&&d===null))return l},this.setFoveation=function(ee){l=ee,f!==null&&(f.fixedFoveation=ee),d!==null&&d.fixedFoveation!==void 0&&(d.fixedFoveation=ee)},this.hasDepthSensing=function(){return g.texture!==null},this.getDepthSensingMesh=function(){return g.getMesh(S)};let W=null;function re(ee,F){if(u=F.getViewerPose(c||o),v=F,u!==null){const xe=u.views;d!==null&&(e.setRenderTargetFramebuffer(x,d.framebuffer),e.setRenderTarget(x));let G=!1;xe.length!==S.cameras.length&&(S.cameras.length=0,G=!0);for(let me=0;me<xe.length;me++){const fe=xe[me];let De=null;if(d!==null)De=d.getViewport(fe);else{const U=h.getViewSubImage(f,fe);De=U.viewport,me===0&&(e.setRenderTargetTextures(x,U.colorTexture,f.ignoreDepthValues?void 0:U.depthStencilTexture),e.setRenderTarget(x))}let se=I[me];se===void 0&&(se=new kn,se.layers.enable(me),se.viewport=new Ct,I[me]=se),se.matrix.fromArray(fe.transform.matrix),se.matrix.decompose(se.position,se.quaternion,se.scale),se.projectionMatrix.fromArray(fe.projectionMatrix),se.projectionMatrixInverse.copy(se.projectionMatrix).invert(),se.viewport.set(De.x,De.y,De.width,De.height),me===0&&(S.matrix.copy(se.matrix),S.matrix.decompose(S.position,S.quaternion,S.scale)),G===!0&&S.cameras.push(se)}const he=r.enabledFeatures;if(he&&he.includes("depth-sensing")){const me=h.getDepthInformation(xe[0]);me&&me.isValid&&me.texture&&g.init(e,me,r.renderState)}}for(let xe=0;xe<_.length;xe++){const G=y[xe],he=_[xe];G!==null&&he!==void 0&&he.update(G,F,c||o)}W&&W(ee,F),F.detectedPlanes&&i.dispatchEvent({type:"planesdetected",data:F}),v=null}const Ae=new J0;Ae.setAnimationLoop(re),this.setAnimationLoop=function(ee){W=ee},this.dispose=function(){}}}const Ir=new Mi,$y=new It;function Yy(n,e){function t(p,m){p.matrixAutoUpdate===!0&&p.updateMatrix(),m.value.copy(p.matrix)}function i(p,m){m.color.getRGB(p.fogColor.value,K0(n)),m.isFog?(p.fogNear.value=m.near,p.fogFar.value=m.far):m.isFogExp2&&(p.fogDensity.value=m.density)}function r(p,m,x,_,y){m.isMeshBasicMaterial||m.isMeshLambertMaterial?s(p,m):m.isMeshToonMaterial?(s(p,m),h(p,m)):m.isMeshPhongMaterial?(s(p,m),u(p,m)):m.isMeshStandardMaterial?(s(p,m),f(p,m),m.isMeshPhysicalMaterial&&d(p,m,y)):m.isMeshMatcapMaterial?(s(p,m),v(p,m)):m.isMeshDepthMaterial?s(p,m):m.isMeshDistanceMaterial?(s(p,m),g(p,m)):m.isMeshNormalMaterial?s(p,m):m.isLineBasicMaterial?(o(p,m),m.isLineDashedMaterial&&a(p,m)):m.isPointsMaterial?l(p,m,x,_):m.isSpriteMaterial?c(p,m):m.isShadowMaterial?(p.color.value.copy(m.color),p.opacity.value=m.opacity):m.isShaderMaterial&&(m.uniformsNeedUpdate=!1)}function s(p,m){p.opacity.value=m.opacity,m.color&&p.diffuse.value.copy(m.color),m.emissive&&p.emissive.value.copy(m.emissive).multiplyScalar(m.emissiveIntensity),m.map&&(p.map.value=m.map,t(m.map,p.mapTransform)),m.alphaMap&&(p.alphaMap.value=m.alphaMap,t(m.alphaMap,p.alphaMapTransform)),m.bumpMap&&(p.bumpMap.value=m.bumpMap,t(m.bumpMap,p.bumpMapTransform),p.bumpScale.value=m.bumpScale,m.side===Kt&&(p.bumpScale.value*=-1)),m.normalMap&&(p.normalMap.value=m.normalMap,t(m.normalMap,p.normalMapTransform),p.normalScale.value.copy(m.normalScale),m.side===Kt&&p.normalScale.value.negate()),m.displacementMap&&(p.displacementMap.value=m.displacementMap,t(m.displacementMap,p.displacementMapTransform),p.displacementScale.value=m.displacementScale,p.displacementBias.value=m.displacementBias),m.emissiveMap&&(p.emissiveMap.value=m.emissiveMap,t(m.emissiveMap,p.emissiveMapTransform)),m.specularMap&&(p.specularMap.value=m.specularMap,t(m.specularMap,p.specularMapTransform)),m.alphaTest>0&&(p.alphaTest.value=m.alphaTest);const x=e.get(m),_=x.envMap,y=x.envMapRotation;_&&(p.envMap.value=_,Ir.copy(y),Ir.x*=-1,Ir.y*=-1,Ir.z*=-1,_.isCubeTexture&&_.isRenderTargetTexture===!1&&(Ir.y*=-1,Ir.z*=-1),p.envMapRotation.value.setFromMatrix4($y.makeRotationFromEuler(Ir)),p.flipEnvMap.value=_.isCubeTexture&&_.isRenderTargetTexture===!1?-1:1,p.reflectivity.value=m.reflectivity,p.ior.value=m.ior,p.refractionRatio.value=m.refractionRatio),m.lightMap&&(p.lightMap.value=m.lightMap,p.lightMapIntensity.value=m.lightMapIntensity,t(m.lightMap,p.lightMapTransform)),m.aoMap&&(p.aoMap.value=m.aoMap,p.aoMapIntensity.value=m.aoMapIntensity,t(m.aoMap,p.aoMapTransform))}function o(p,m){p.diffuse.value.copy(m.color),p.opacity.value=m.opacity,m.map&&(p.map.value=m.map,t(m.map,p.mapTransform))}function a(p,m){p.dashSize.value=m.dashSize,p.totalSize.value=m.dashSize+m.gapSize,p.scale.value=m.scale}function l(p,m,x,_){p.diffuse.value.copy(m.color),p.opacity.value=m.opacity,p.size.value=m.size*x,p.scale.value=_*.5,m.map&&(p.map.value=m.map,t(m.map,p.uvTransform)),m.alphaMap&&(p.alphaMap.value=m.alphaMap,t(m.alphaMap,p.alphaMapTransform)),m.alphaTest>0&&(p.alphaTest.value=m.alphaTest)}function c(p,m){p.diffuse.value.copy(m.color),p.opacity.value=m.opacity,p.rotation.value=m.rotation,m.map&&(p.map.value=m.map,t(m.map,p.mapTransform)),m.alphaMap&&(p.alphaMap.value=m.alphaMap,t(m.alphaMap,p.alphaMapTransform)),m.alphaTest>0&&(p.alphaTest.value=m.alphaTest)}function u(p,m){p.specular.value.copy(m.specular),p.shininess.value=Math.max(m.shininess,1e-4)}function h(p,m){m.gradientMap&&(p.gradientMap.value=m.gradientMap)}function f(p,m){p.metalness.value=m.metalness,m.metalnessMap&&(p.metalnessMap.value=m.metalnessMap,t(m.metalnessMap,p.metalnessMapTransform)),p.roughness.value=m.roughness,m.roughnessMap&&(p.roughnessMap.value=m.roughnessMap,t(m.roughnessMap,p.roughnessMapTransform)),m.envMap&&(p.envMapIntensity.value=m.envMapIntensity)}function d(p,m,x){p.ior.value=m.ior,m.sheen>0&&(p.sheenColor.value.copy(m.sheenColor).multiplyScalar(m.sheen),p.sheenRoughness.value=m.sheenRoughness,m.sheenColorMap&&(p.sheenColorMap.value=m.sheenColorMap,t(m.sheenColorMap,p.sheenColorMapTransform)),m.sheenRoughnessMap&&(p.sheenRoughnessMap.value=m.sheenRoughnessMap,t(m.sheenRoughnessMap,p.sheenRoughnessMapTransform))),m.clearcoat>0&&(p.clearcoat.value=m.clearcoat,p.clearcoatRoughness.value=m.clearcoatRoughness,m.clearcoatMap&&(p.clearcoatMap.value=m.clearcoatMap,t(m.clearcoatMap,p.clearcoatMapTransform)),m.clearcoatRoughnessMap&&(p.clearcoatRoughnessMap.value=m.clearcoatRoughnessMap,t(m.clearcoatRoughnessMap,p.clearcoatRoughnessMapTransform)),m.clearcoatNormalMap&&(p.clearcoatNormalMap.value=m.clearcoatNormalMap,t(m.clearcoatNormalMap,p.clearcoatNormalMapTransform),p.clearcoatNormalScale.value.copy(m.clearcoatNormalScale),m.side===Kt&&p.clearcoatNormalScale.value.negate())),m.dispersion>0&&(p.dispersion.value=m.dispersion),m.iridescence>0&&(p.iridescence.value=m.iridescence,p.iridescenceIOR.value=m.iridescenceIOR,p.iridescenceThicknessMinimum.value=m.iridescenceThicknessRange[0],p.iridescenceThicknessMaximum.value=m.iridescenceThicknessRange[1],m.iridescenceMap&&(p.iridescenceMap.value=m.iridescenceMap,t(m.iridescenceMap,p.iridescenceMapTransform)),m.iridescenceThicknessMap&&(p.iridescenceThicknessMap.value=m.iridescenceThicknessMap,t(m.iridescenceThicknessMap,p.iridescenceThicknessMapTransform))),m.transmission>0&&(p.transmission.value=m.transmission,p.transmissionSamplerMap.value=x.texture,p.transmissionSamplerSize.value.set(x.width,x.height),m.transmissionMap&&(p.transmissionMap.value=m.transmissionMap,t(m.transmissionMap,p.transmissionMapTransform)),p.thickness.value=m.thickness,m.thicknessMap&&(p.thicknessMap.value=m.thicknessMap,t(m.thicknessMap,p.thicknessMapTransform)),p.attenuationDistance.value=m.attenuationDistance,p.attenuationColor.value.copy(m.attenuationColor)),m.anisotropy>0&&(p.anisotropyVector.value.set(m.anisotropy*Math.cos(m.anisotropyRotation),m.anisotropy*Math.sin(m.anisotropyRotation)),m.anisotropyMap&&(p.anisotropyMap.value=m.anisotropyMap,t(m.anisotropyMap,p.anisotropyMapTransform))),p.specularIntensity.value=m.specularIntensity,p.specularColor.value.copy(m.specularColor),m.specularColorMap&&(p.specularColorMap.value=m.specularColorMap,t(m.specularColorMap,p.specularColorMapTransform)),m.specularIntensityMap&&(p.specularIntensityMap.value=m.specularIntensityMap,t(m.specularIntensityMap,p.specularIntensityMapTransform))}function v(p,m){m.matcap&&(p.matcap.value=m.matcap)}function g(p,m){const x=e.get(m).light;p.referencePosition.value.setFromMatrixPosition(x.matrixWorld),p.nearDistance.value=x.shadow.camera.near,p.farDistance.value=x.shadow.camera.far}return{refreshFogUniforms:i,refreshMaterialUniforms:r}}function Ky(n,e,t,i){let r={},s={},o=[];const a=n.getParameter(n.MAX_UNIFORM_BUFFER_BINDINGS);function l(x,_){const y=_.program;i.uniformBlockBinding(x,y)}function c(x,_){let y=r[x.id];y===void 0&&(v(x),y=u(x),r[x.id]=y,x.addEventListener("dispose",p));const C=_.program;i.updateUBOMapping(x,C);const M=e.render.frame;s[x.id]!==M&&(f(x),s[x.id]=M)}function u(x){const _=h();x.__bindingPointIndex=_;const y=n.createBuffer(),C=x.__size,M=x.usage;return n.bindBuffer(n.UNIFORM_BUFFER,y),n.bufferData(n.UNIFORM_BUFFER,C,M),n.bindBuffer(n.UNIFORM_BUFFER,null),n.bindBufferBase(n.UNIFORM_BUFFER,_,y),y}function h(){for(let x=0;x<a;x++)if(o.indexOf(x)===-1)return o.push(x),x;return console.error("THREE.WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function f(x){const _=r[x.id],y=x.uniforms,C=x.__cache;n.bindBuffer(n.UNIFORM_BUFFER,_);for(let M=0,w=y.length;M<w;M++){const P=Array.isArray(y[M])?y[M]:[y[M]];for(let I=0,S=P.length;I<S;I++){const b=P[I];if(d(b,M,I,C)===!0){const N=b.__offset,R=Array.isArray(b.value)?b.value:[b.value];let H=0;for(let T=0;T<R.length;T++){const k=R[T],Z=g(k);typeof k=="number"||typeof k=="boolean"?(b.__data[0]=k,n.bufferSubData(n.UNIFORM_BUFFER,N+H,b.__data)):k.isMatrix3?(b.__data[0]=k.elements[0],b.__data[1]=k.elements[1],b.__data[2]=k.elements[2],b.__data[3]=0,b.__data[4]=k.elements[3],b.__data[5]=k.elements[4],b.__data[6]=k.elements[5],b.__data[7]=0,b.__data[8]=k.elements[6],b.__data[9]=k.elements[7],b.__data[10]=k.elements[8],b.__data[11]=0):(k.toArray(b.__data,H),H+=Z.storage/Float32Array.BYTES_PER_ELEMENT)}n.bufferSubData(n.UNIFORM_BUFFER,N,b.__data)}}}n.bindBuffer(n.UNIFORM_BUFFER,null)}function d(x,_,y,C){const M=x.value,w=_+"_"+y;if(C[w]===void 0)return typeof M=="number"||typeof M=="boolean"?C[w]=M:C[w]=M.clone(),!0;{const P=C[w];if(typeof M=="number"||typeof M=="boolean"){if(P!==M)return C[w]=M,!0}else if(P.equals(M)===!1)return P.copy(M),!0}return!1}function v(x){const _=x.uniforms;let y=0;const C=16;for(let w=0,P=_.length;w<P;w++){const I=Array.isArray(_[w])?_[w]:[_[w]];for(let S=0,b=I.length;S<b;S++){const N=I[S],R=Array.isArray(N.value)?N.value:[N.value];for(let H=0,T=R.length;H<T;H++){const k=R[H],Z=g(k),K=y%C,pe=K%Z.boundary,ce=K+pe;y+=pe,ce!==0&&C-ce<Z.storage&&(y+=C-ce),N.__data=new Float32Array(Z.storage/Float32Array.BYTES_PER_ELEMENT),N.__offset=y,y+=Z.storage}}}const M=y%C;return M>0&&(y+=C-M),x.__size=y,x.__cache={},this}function g(x){const _={boundary:0,storage:0};return typeof x=="number"||typeof x=="boolean"?(_.boundary=4,_.storage=4):x.isVector2?(_.boundary=8,_.storage=8):x.isVector3||x.isColor?(_.boundary=16,_.storage=12):x.isVector4?(_.boundary=16,_.storage=16):x.isMatrix3?(_.boundary=48,_.storage=48):x.isMatrix4?(_.boundary=64,_.storage=64):x.isTexture?console.warn("THREE.WebGLRenderer: Texture samplers can not be part of an uniforms group."):console.warn("THREE.WebGLRenderer: Unsupported uniform value type.",x),_}function p(x){const _=x.target;_.removeEventListener("dispose",p);const y=o.indexOf(_.__bindingPointIndex);o.splice(y,1),n.deleteBuffer(r[_.id]),delete r[_.id],delete s[_.id]}function m(){for(const x in r)n.deleteBuffer(r[x]);o=[],r={},s={}}return{bind:l,update:c,dispose:m}}class jy{constructor(e={}){const{canvas:t=Fg(),context:i=null,depth:r=!0,stencil:s=!1,alpha:o=!1,antialias:a=!1,premultipliedAlpha:l=!0,preserveDrawingBuffer:c=!1,powerPreference:u="default",failIfMajorPerformanceCaveat:h=!1}=e;this.isWebGLRenderer=!0;let f;if(i!==null){if(typeof WebGLRenderingContext<"u"&&i instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");f=i.getContextAttributes().alpha}else f=o;const d=new Uint32Array(4),v=new Int32Array(4);let g=null,p=null;const m=[],x=[];this.domElement=t,this.debug={checkShaderErrors:!0,onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this._outputColorSpace=wt,this.toneMapping=ki,this.toneMappingExposure=1;const _=this;let y=!1,C=0,M=0,w=null,P=-1,I=null;const S=new Ct,b=new Ct;let N=null;const R=new st(0);let H=0,T=t.width,k=t.height,Z=1,K=null,pe=null;const ce=new Ct(0,0,T,k),W=new Ct(0,0,T,k);let re=!1;const Ae=new Z0;let ee=!1,F=!1;const xe=new It,G=new It,he=new O,me=new Ct,fe={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0};let De=!1;function se(){return w===null?Z:1}let U=i;function Se(L,Y){return t.getContext(L,Y)}try{const L={alpha:!0,depth:r,stencil:s,antialias:a,premultipliedAlpha:l,preserveDrawingBuffer:c,powerPreference:u,failIfMajorPerformanceCaveat:h};if("setAttribute"in t&&t.setAttribute("data-engine",`three.js r${ua}`),t.addEventListener("webglcontextlost",le,!1),t.addEventListener("webglcontextrestored",Te,!1),t.addEventListener("webglcontextcreationerror",_e,!1),U===null){const Y="webgl2";if(U=Se(Y,L),U===null)throw Se(Y)?new Error("Error creating WebGL context with your selected attributes."):new Error("Error creating WebGL context.")}}catch(L){throw console.error("THREE.WebGLRenderer: "+L.message),L}let ye,ge,B,q,V,A,E,z,$,ne,te,ve,ue,Me,Re,de,Ee,Ne,Ve,Pe,Xe,We,dt,X;function ie(){ye=new tx(U),ye.init(),We=new zy(U,ye),ge=new Y1(U,ye,e,We),B=new Oy(U),ge.reverseDepthBuffer&&B.buffers.depth.setReversed(!0),q=new rx(U),V=new My,A=new By(U,ye,B,V,ge,We,q),E=new j1(_),z=new ex(_),$=new uv(U),dt=new q1(U,$),ne=new nx(U,$,q,dt),te=new ox(U,ne,$,q),Ve=new sx(U,ge,A),de=new K1(V),ve=new Sy(_,E,z,ye,ge,dt,de),ue=new Yy(_,V),Me=new wy,Re=new Py(ye),Ne=new X1(_,E,z,B,te,f,l),Ee=new Ny(_,te,ge),X=new Ky(U,q,ge,B),Pe=new $1(U,ye,q),Xe=new ix(U,ye,q),q.programs=ve.programs,_.capabilities=ge,_.extensions=ye,_.properties=V,_.renderLists=Me,_.shadowMap=Ee,_.state=B,_.info=q}ie();const Q=new qy(_,U);this.xr=Q,this.getContext=function(){return U},this.getContextAttributes=function(){return U.getContextAttributes()},this.forceContextLoss=function(){const L=ye.get("WEBGL_lose_context");L&&L.loseContext()},this.forceContextRestore=function(){const L=ye.get("WEBGL_lose_context");L&&L.restoreContext()},this.getPixelRatio=function(){return Z},this.setPixelRatio=function(L){L!==void 0&&(Z=L,this.setSize(T,k,!1))},this.getSize=function(L){return L.set(T,k)},this.setSize=function(L,Y,oe=!0){if(Q.isPresenting){console.warn("THREE.WebGLRenderer: Can't change size while VR device is presenting.");return}T=L,k=Y,t.width=Math.floor(L*Z),t.height=Math.floor(Y*Z),oe===!0&&(t.style.width=L+"px",t.style.height=Y+"px"),this.setViewport(0,0,L,Y)},this.getDrawingBufferSize=function(L){return L.set(T*Z,k*Z).floor()},this.setDrawingBufferSize=function(L,Y,oe){T=L,k=Y,Z=oe,t.width=Math.floor(L*oe),t.height=Math.floor(Y*oe),this.setViewport(0,0,L,Y)},this.getCurrentViewport=function(L){return L.copy(S)},this.getViewport=function(L){return L.copy(ce)},this.setViewport=function(L,Y,oe,ae){L.isVector4?ce.set(L.x,L.y,L.z,L.w):ce.set(L,Y,oe,ae),B.viewport(S.copy(ce).multiplyScalar(Z).round())},this.getScissor=function(L){return L.copy(W)},this.setScissor=function(L,Y,oe,ae){L.isVector4?W.set(L.x,L.y,L.z,L.w):W.set(L,Y,oe,ae),B.scissor(b.copy(W).multiplyScalar(Z).round())},this.getScissorTest=function(){return re},this.setScissorTest=function(L){B.setScissorTest(re=L)},this.setOpaqueSort=function(L){K=L},this.setTransparentSort=function(L){pe=L},this.getClearColor=function(L){return L.copy(Ne.getClearColor())},this.setClearColor=function(){Ne.setClearColor.apply(Ne,arguments)},this.getClearAlpha=function(){return Ne.getClearAlpha()},this.setClearAlpha=function(){Ne.setClearAlpha.apply(Ne,arguments)},this.clear=function(L=!0,Y=!0,oe=!0){let ae=0;if(L){let j=!1;if(w!==null){const Ce=w.texture.format;j=Ce===Dh||Ce===Lh||Ce===Ph}if(j){const Ce=w.texture.type,Ue=Ce===on||Ce===xr||Ce===jo||Ce===Jr||Ce===Ch||Ce===Rh,ke=Ne.getClearColor(),He=Ne.getClearAlpha(),Ze=ke.r,$e=ke.g,Ge=ke.b;Ue?(d[0]=Ze,d[1]=$e,d[2]=Ge,d[3]=He,U.clearBufferuiv(U.COLOR,0,d)):(v[0]=Ze,v[1]=$e,v[2]=Ge,v[3]=He,U.clearBufferiv(U.COLOR,0,v))}else ae|=U.COLOR_BUFFER_BIT}Y&&(ae|=U.DEPTH_BUFFER_BIT,U.clearDepth(this.capabilities.reverseDepthBuffer?0:1)),oe&&(ae|=U.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),U.clear(ae)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.dispose=function(){t.removeEventListener("webglcontextlost",le,!1),t.removeEventListener("webglcontextrestored",Te,!1),t.removeEventListener("webglcontextcreationerror",_e,!1),Me.dispose(),Re.dispose(),V.dispose(),E.dispose(),z.dispose(),te.dispose(),dt.dispose(),X.dispose(),ve.dispose(),Q.dispose(),Q.removeEventListener("sessionstart",Ti),Q.removeEventListener("sessionend",Dn),qn.stop()};function le(L){L.preventDefault(),console.log("THREE.WebGLRenderer: Context Lost."),y=!0}function Te(){console.log("THREE.WebGLRenderer: Context Restored."),y=!1;const L=q.autoReset,Y=Ee.enabled,oe=Ee.autoUpdate,ae=Ee.needsUpdate,j=Ee.type;ie(),q.autoReset=L,Ee.enabled=Y,Ee.autoUpdate=oe,Ee.needsUpdate=ae,Ee.type=j}function _e(L){console.error("THREE.WebGLRenderer: A WebGL context could not be created. Reason: ",L.statusMessage)}function qe(L){const Y=L.target;Y.removeEventListener("dispose",qe),rt(Y)}function rt(L){Lt(L),V.remove(L)}function Lt(L){const Y=V.get(L).programs;Y!==void 0&&(Y.forEach(function(oe){ve.releaseProgram(oe)}),L.isShaderMaterial&&ve.releaseShaderCache(L))}this.renderBufferDirect=function(L,Y,oe,ae,j,Ce){Y===null&&(Y=fe);const Ue=j.isMesh&&j.matrixWorld.determinant()<0,ke=yo(L,Y,oe,ae,j);B.setMaterial(ae,Ue);let He=oe.index,Ze=1;if(ae.wireframe===!0){if(He=ne.getWireframeAttribute(oe),He===void 0)return;Ze=2}const $e=oe.drawRange,Ge=oe.attributes.position;let ct=$e.start*Ze,vt=($e.start+$e.count)*Ze;Ce!==null&&(ct=Math.max(ct,Ce.start*Ze),vt=Math.min(vt,(Ce.start+Ce.count)*Ze)),He!==null?(ct=Math.max(ct,0),vt=Math.min(vt,He.count)):Ge!=null&&(ct=Math.max(ct,0),vt=Math.min(vt,Ge.count));const Tt=vt-ct;if(Tt<0||Tt===1/0)return;dt.setup(j,ae,ke,oe,He);let gn,ut=Pe;if(He!==null&&(gn=$.get(He),ut=Xe,ut.setIndex(gn)),j.isMesh)ae.wireframe===!0?(B.setLineWidth(ae.wireframeLinewidth*se()),ut.setMode(U.LINES)):ut.setMode(U.TRIANGLES);else if(j.isLine){let Be=ae.linewidth;Be===void 0&&(Be=1),B.setLineWidth(Be*se()),j.isLineSegments?ut.setMode(U.LINES):j.isLineLoop?ut.setMode(U.LINE_LOOP):ut.setMode(U.LINE_STRIP)}else j.isPoints?ut.setMode(U.POINTS):j.isSprite&&ut.setMode(U.TRIANGLES);if(j.isBatchedMesh)if(j._multiDrawInstances!==null)ut.renderMultiDrawInstances(j._multiDrawStarts,j._multiDrawCounts,j._multiDrawCount,j._multiDrawInstances);else if(ye.get("WEBGL_multi_draw"))ut.renderMultiDraw(j._multiDrawStarts,j._multiDrawCounts,j._multiDrawCount);else{const Be=j._multiDrawStarts,Vt=j._multiDrawCounts,ot=j._multiDrawCount,Yt=He?$.get(He).bytesPerElement:1,qi=V.get(ae).currentProgram.getUniforms();for(let an=0;an<ot;an++)qi.setValue(U,"_gl_DrawID",an),ut.render(Be[an]/Yt,Vt[an])}else if(j.isInstancedMesh)ut.renderInstances(ct,Tt,j.count);else if(oe.isInstancedBufferGeometry){const Be=oe._maxInstanceCount!==void 0?oe._maxInstanceCount:1/0,Vt=Math.min(oe.instanceCount,Be);ut.renderInstances(ct,Tt,Vt)}else ut.render(ct,Tt)};function Je(L,Y,oe){L.transparent===!0&&L.side===Tn&&L.forceSinglePass===!1?(L.side=Kt,L.needsUpdate=!0,us(L,Y,oe),L.side=zi,L.needsUpdate=!0,us(L,Y,oe),L.side=Tn):us(L,Y,oe)}this.compile=function(L,Y,oe=null){oe===null&&(oe=L),p=Re.get(oe),p.init(Y),x.push(p),oe.traverseVisible(function(j){j.isLight&&j.layers.test(Y.layers)&&(p.pushLight(j),j.castShadow&&p.pushShadow(j))}),L!==oe&&L.traverseVisible(function(j){j.isLight&&j.layers.test(Y.layers)&&(p.pushLight(j),j.castShadow&&p.pushShadow(j))}),p.setupLights();const ae=new Set;return L.traverse(function(j){if(!(j.isMesh||j.isPoints||j.isLine||j.isSprite))return;const Ce=j.material;if(Ce)if(Array.isArray(Ce))for(let Ue=0;Ue<Ce.length;Ue++){const ke=Ce[Ue];Je(ke,oe,j),ae.add(ke)}else Je(Ce,oe,j),ae.add(Ce)}),x.pop(),p=null,ae},this.compileAsync=function(L,Y,oe=null){const ae=this.compile(L,Y,oe);return new Promise(j=>{function Ce(){if(ae.forEach(function(Ue){V.get(Ue).currentProgram.isReady()&&ae.delete(Ue)}),ae.size===0){j(L);return}setTimeout(Ce,10)}ye.get("KHR_parallel_shader_compile")!==null?Ce():setTimeout(Ce,10)})};let yt=null;function Jt(L){yt&&yt(L)}function Ti(){qn.stop()}function Dn(){qn.start()}const qn=new J0;qn.setAnimationLoop(Jt),typeof self<"u"&&qn.setContext(self),this.setAnimationLoop=function(L){yt=L,Q.setAnimationLoop(L),L===null?qn.stop():qn.start()},Q.addEventListener("sessionstart",Ti),Q.addEventListener("sessionend",Dn),this.render=function(L,Y){if(Y!==void 0&&Y.isCamera!==!0){console.error("THREE.WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(y===!0)return;if(L.matrixWorldAutoUpdate===!0&&L.updateMatrixWorld(),Y.parent===null&&Y.matrixWorldAutoUpdate===!0&&Y.updateMatrixWorld(),Q.enabled===!0&&Q.isPresenting===!0&&(Q.cameraAutoUpdate===!0&&Q.updateCamera(Y),Y=Q.getCamera()),L.isScene===!0&&L.onBeforeRender(_,L,Y,w),p=Re.get(L,x.length),p.init(Y),x.push(p),G.multiplyMatrices(Y.projectionMatrix,Y.matrixWorldInverse),Ae.setFromProjectionMatrix(G),F=this.localClippingEnabled,ee=de.init(this.clippingPlanes,F),g=Me.get(L,m.length),g.init(),m.push(g),Q.enabled===!0&&Q.isPresenting===!0){const Ce=_.xr.getDepthSensingMesh();Ce!==null&&Xi(Ce,Y,-1/0,_.sortObjects)}Xi(L,Y,0,_.sortObjects),g.finish(),_.sortObjects===!0&&g.sort(K,pe),De=Q.enabled===!1||Q.isPresenting===!1||Q.hasDepthSensing()===!1,De&&Ne.addToRenderList(g,L),this.info.render.frame++,ee===!0&&de.beginShadows();const oe=p.state.shadowsArray;Ee.render(oe,L,Y),ee===!0&&de.endShadows(),this.info.autoReset===!0&&this.info.reset();const ae=g.opaque,j=g.transmissive;if(p.setupLights(),Y.isArrayCamera){const Ce=Y.cameras;if(j.length>0)for(let Ue=0,ke=Ce.length;Ue<ke;Ue++){const He=Ce[Ue];cs(ae,j,L,He)}De&&Ne.render(L);for(let Ue=0,ke=Ce.length;Ue<ke;Ue++){const He=Ce[Ue];_o(g,L,He,He.viewport)}}else j.length>0&&cs(ae,j,L,Y),De&&Ne.render(L),_o(g,L,Y);w!==null&&(A.updateMultisampleRenderTarget(w),A.updateRenderTargetMipmap(w)),L.isScene===!0&&L.onAfterRender(_,L,Y),dt.resetDefaultState(),P=-1,I=null,x.pop(),x.length>0?(p=x[x.length-1],ee===!0&&de.setGlobalState(_.clippingPlanes,p.state.camera)):p=null,m.pop(),m.length>0?g=m[m.length-1]:g=null};function Xi(L,Y,oe,ae){if(L.visible===!1)return;if(L.layers.test(Y.layers)){if(L.isGroup)oe=L.renderOrder;else if(L.isLOD)L.autoUpdate===!0&&L.update(Y);else if(L.isLight)p.pushLight(L),L.castShadow&&p.pushShadow(L);else if(L.isSprite){if(!L.frustumCulled||Ae.intersectsSprite(L)){ae&&me.setFromMatrixPosition(L.matrixWorld).applyMatrix4(G);const Ue=te.update(L),ke=L.material;ke.visible&&g.push(L,Ue,ke,oe,me.z,null)}}else if((L.isMesh||L.isLine||L.isPoints)&&(!L.frustumCulled||Ae.intersectsObject(L))){const Ue=te.update(L),ke=L.material;if(ae&&(L.boundingSphere!==void 0?(L.boundingSphere===null&&L.computeBoundingSphere(),me.copy(L.boundingSphere.center)):(Ue.boundingSphere===null&&Ue.computeBoundingSphere(),me.copy(Ue.boundingSphere.center)),me.applyMatrix4(L.matrixWorld).applyMatrix4(G)),Array.isArray(ke)){const He=Ue.groups;for(let Ze=0,$e=He.length;Ze<$e;Ze++){const Ge=He[Ze],ct=ke[Ge.materialIndex];ct&&ct.visible&&g.push(L,Ue,ct,oe,me.z,Ge)}}else ke.visible&&g.push(L,Ue,ke,oe,me.z,null)}}const Ce=L.children;for(let Ue=0,ke=Ce.length;Ue<ke;Ue++)Xi(Ce[Ue],Y,oe,ae)}function _o(L,Y,oe,ae){const j=L.opaque,Ce=L.transmissive,Ue=L.transparent;p.setupLightsView(oe),ee===!0&&de.setGlobalState(_.clippingPlanes,oe),ae&&B.viewport(S.copy(ae)),j.length>0&&Er(j,Y,oe),Ce.length>0&&Er(Ce,Y,oe),Ue.length>0&&Er(Ue,Y,oe),B.buffers.depth.setTest(!0),B.buffers.depth.setMask(!0),B.buffers.color.setMask(!0),B.setPolygonOffset(!1)}function cs(L,Y,oe,ae){if((oe.isScene===!0?oe.overrideMaterial:null)!==null)return;p.state.transmissionRenderTarget[ae.id]===void 0&&(p.state.transmissionRenderTarget[ae.id]=new Sn(1,1,{generateMipmaps:!0,type:ye.has("EXT_color_buffer_half_float")||ye.has("EXT_color_buffer_float")?ho:on,minFilter:lr,samples:4,stencilBuffer:s,resolveDepthBuffer:!1,resolveStencilBuffer:!1,colorSpace:gt.workingColorSpace}));const Ce=p.state.transmissionRenderTarget[ae.id],Ue=ae.viewport||S;Ce.setSize(Ue.z,Ue.w);const ke=_.getRenderTarget();_.setRenderTarget(Ce),_.getClearColor(R),H=_.getClearAlpha(),H<1&&_.setClearColor(16777215,.5),_.clear(),De&&Ne.render(oe);const He=_.toneMapping;_.toneMapping=ki;const Ze=ae.viewport;if(ae.viewport!==void 0&&(ae.viewport=void 0),p.setupLightsView(ae),ee===!0&&de.setGlobalState(_.clippingPlanes,ae),Er(L,oe,ae),A.updateMultisampleRenderTarget(Ce),A.updateRenderTargetMipmap(Ce),ye.has("WEBGL_multisampled_render_to_texture")===!1){let $e=!1;for(let Ge=0,ct=Y.length;Ge<ct;Ge++){const vt=Y[Ge],Tt=vt.object,gn=vt.geometry,ut=vt.material,Be=vt.group;if(ut.side===Tn&&Tt.layers.test(ae.layers)){const Vt=ut.side;ut.side=Kt,ut.needsUpdate=!0,li(Tt,oe,ae,gn,ut,Be),ut.side=Vt,ut.needsUpdate=!0,$e=!0}}$e===!0&&(A.updateMultisampleRenderTarget(Ce),A.updateRenderTargetMipmap(Ce))}_.setRenderTarget(ke),_.setClearColor(R,H),Ze!==void 0&&(ae.viewport=Ze),_.toneMapping=He}function Er(L,Y,oe){const ae=Y.isScene===!0?Y.overrideMaterial:null;for(let j=0,Ce=L.length;j<Ce;j++){const Ue=L[j],ke=Ue.object,He=Ue.geometry,Ze=ae===null?Ue.material:ae,$e=Ue.group;ke.layers.test(oe.layers)&&li(ke,Y,oe,He,Ze,$e)}}function li(L,Y,oe,ae,j,Ce){L.onBeforeRender(_,Y,oe,ae,j,Ce),L.modelViewMatrix.multiplyMatrices(oe.matrixWorldInverse,L.matrixWorld),L.normalMatrix.getNormalMatrix(L.modelViewMatrix),j.onBeforeRender(_,Y,oe,ae,L,Ce),j.transparent===!0&&j.side===Tn&&j.forceSinglePass===!1?(j.side=Kt,j.needsUpdate=!0,_.renderBufferDirect(oe,Y,ae,j,L,Ce),j.side=zi,j.needsUpdate=!0,_.renderBufferDirect(oe,Y,ae,j,L,Ce),j.side=Tn):_.renderBufferDirect(oe,Y,ae,j,L,Ce),L.onAfterRender(_,Y,oe,ae,j,Ce)}function us(L,Y,oe){Y.isScene!==!0&&(Y=fe);const ae=V.get(L),j=p.state.lights,Ce=p.state.shadowsArray,Ue=j.state.version,ke=ve.getParameters(L,j.state,Ce,Y,oe),He=ve.getProgramCacheKey(ke);let Ze=ae.programs;ae.environment=L.isMeshStandardMaterial?Y.environment:null,ae.fog=Y.fog,ae.envMap=(L.isMeshStandardMaterial?z:E).get(L.envMap||ae.environment),ae.envMapRotation=ae.environment!==null&&L.envMap===null?Y.environmentRotation:L.envMapRotation,Ze===void 0&&(L.addEventListener("dispose",qe),Ze=new Map,ae.programs=Ze);let $e=Ze.get(He);if($e!==void 0){if(ae.currentProgram===$e&&ae.lightsStateVersion===Ue)return xo(L,ke),$e}else ke.uniforms=ve.getUniforms(L),L.onBeforeCompile(ke,_),$e=ve.acquireProgram(ke,He),Ze.set(He,$e),ae.uniforms=ke.uniforms;const Ge=ae.uniforms;return(!L.isShaderMaterial&&!L.isRawShaderMaterial||L.clipping===!0)&&(Ge.clippingPlanes=de.uniform),xo(L,ke),ae.needsLights=Tr(L),ae.lightsStateVersion=Ue,ae.needsLights&&(Ge.ambientLightColor.value=j.state.ambient,Ge.lightProbe.value=j.state.probe,Ge.directionalLights.value=j.state.directional,Ge.directionalLightShadows.value=j.state.directionalShadow,Ge.spotLights.value=j.state.spot,Ge.spotLightShadows.value=j.state.spotShadow,Ge.rectAreaLights.value=j.state.rectArea,Ge.ltc_1.value=j.state.rectAreaLTC1,Ge.ltc_2.value=j.state.rectAreaLTC2,Ge.pointLights.value=j.state.point,Ge.pointLightShadows.value=j.state.pointShadow,Ge.hemisphereLights.value=j.state.hemi,Ge.directionalShadowMap.value=j.state.directionalShadowMap,Ge.directionalShadowMatrix.value=j.state.directionalShadowMatrix,Ge.spotShadowMap.value=j.state.spotShadowMap,Ge.spotLightMatrix.value=j.state.spotLightMatrix,Ge.spotLightMap.value=j.state.spotLightMap,Ge.pointShadowMap.value=j.state.pointShadowMap,Ge.pointShadowMatrix.value=j.state.pointShadowMatrix),ae.currentProgram=$e,ae.uniformsList=null,$e}function ma(L){if(L.uniformsList===null){const Y=L.currentProgram.getUniforms();L.uniformsList=hl.seqWithValue(Y.seq,L.uniforms)}return L.uniformsList}function xo(L,Y){const oe=V.get(L);oe.outputColorSpace=Y.outputColorSpace,oe.batching=Y.batching,oe.batchingColor=Y.batchingColor,oe.instancing=Y.instancing,oe.instancingColor=Y.instancingColor,oe.instancingMorph=Y.instancingMorph,oe.skinning=Y.skinning,oe.morphTargets=Y.morphTargets,oe.morphNormals=Y.morphNormals,oe.morphColors=Y.morphColors,oe.morphTargetsCount=Y.morphTargetsCount,oe.numClippingPlanes=Y.numClippingPlanes,oe.numIntersection=Y.numClipIntersection,oe.vertexAlphas=Y.vertexAlphas,oe.vertexTangents=Y.vertexTangents,oe.toneMapping=Y.toneMapping}function yo(L,Y,oe,ae,j){Y.isScene!==!0&&(Y=fe),A.resetTextureUnits();const Ce=Y.fog,Ue=ae.isMeshStandardMaterial?Y.environment:null,ke=w===null?_.outputColorSpace:w.isXRRenderTarget===!0?w.texture.colorSpace:wi,He=(ae.isMeshStandardMaterial?z:E).get(ae.envMap||Ue),Ze=ae.vertexColors===!0&&!!oe.attributes.color&&oe.attributes.color.itemSize===4,$e=!!oe.attributes.tangent&&(!!ae.normalMap||ae.anisotropy>0),Ge=!!oe.morphAttributes.position,ct=!!oe.morphAttributes.normal,vt=!!oe.morphAttributes.color;let Tt=ki;ae.toneMapped&&(w===null||w.isXRRenderTarget===!0)&&(Tt=_.toneMapping);const gn=oe.morphAttributes.position||oe.morphAttributes.normal||oe.morphAttributes.color,ut=gn!==void 0?gn.length:0,Be=V.get(ae),Vt=p.state.lights;if(ee===!0&&(F===!0||L!==I)){const Mn=L===I&&ae.id===P;de.setState(ae,L,Mn)}let ot=!1;ae.version===Be.__version?(Be.needsLights&&Be.lightsStateVersion!==Vt.state.version||Be.outputColorSpace!==ke||j.isBatchedMesh&&Be.batching===!1||!j.isBatchedMesh&&Be.batching===!0||j.isBatchedMesh&&Be.batchingColor===!0&&j.colorTexture===null||j.isBatchedMesh&&Be.batchingColor===!1&&j.colorTexture!==null||j.isInstancedMesh&&Be.instancing===!1||!j.isInstancedMesh&&Be.instancing===!0||j.isSkinnedMesh&&Be.skinning===!1||!j.isSkinnedMesh&&Be.skinning===!0||j.isInstancedMesh&&Be.instancingColor===!0&&j.instanceColor===null||j.isInstancedMesh&&Be.instancingColor===!1&&j.instanceColor!==null||j.isInstancedMesh&&Be.instancingMorph===!0&&j.morphTexture===null||j.isInstancedMesh&&Be.instancingMorph===!1&&j.morphTexture!==null||Be.envMap!==He||ae.fog===!0&&Be.fog!==Ce||Be.numClippingPlanes!==void 0&&(Be.numClippingPlanes!==de.numPlanes||Be.numIntersection!==de.numIntersection)||Be.vertexAlphas!==Ze||Be.vertexTangents!==$e||Be.morphTargets!==Ge||Be.morphNormals!==ct||Be.morphColors!==vt||Be.toneMapping!==Tt||Be.morphTargetsCount!==ut)&&(ot=!0):(ot=!0,Be.__version=ae.version);let Yt=Be.currentProgram;ot===!0&&(Yt=us(ae,Y,j));let qi=!1,an=!1,hs=!1;const Rt=Yt.getUniforms(),ci=Be.uniforms;if(B.useProgram(Yt.program)&&(qi=!0,an=!0,hs=!0),ae.id!==P&&(P=ae.id,an=!0),qi||I!==L){ge.reverseDepthBuffer?(xe.copy(L.projectionMatrix),kg(xe),Bg(xe),Rt.setValue(U,"projectionMatrix",xe)):Rt.setValue(U,"projectionMatrix",L.projectionMatrix),Rt.setValue(U,"viewMatrix",L.matrixWorldInverse);const Mn=Rt.map.cameraPosition;Mn!==void 0&&Mn.setValue(U,he.setFromMatrixPosition(L.matrixWorld)),ge.logarithmicDepthBuffer&&Rt.setValue(U,"logDepthBufFC",2/(Math.log(L.far+1)/Math.LN2)),(ae.isMeshPhongMaterial||ae.isMeshToonMaterial||ae.isMeshLambertMaterial||ae.isMeshBasicMaterial||ae.isMeshStandardMaterial||ae.isShaderMaterial)&&Rt.setValue(U,"isOrthographic",L.isOrthographicCamera===!0),I!==L&&(I=L,an=!0,hs=!0)}if(j.isSkinnedMesh){Rt.setOptional(U,j,"bindMatrix"),Rt.setOptional(U,j,"bindMatrixInverse");const Mn=j.skeleton;Mn&&(Mn.boneTexture===null&&Mn.computeBoneTexture(),Rt.setValue(U,"boneTexture",Mn.boneTexture,A))}j.isBatchedMesh&&(Rt.setOptional(U,j,"batchingTexture"),Rt.setValue(U,"batchingTexture",j._matricesTexture,A),Rt.setOptional(U,j,"batchingIdTexture"),Rt.setValue(U,"batchingIdTexture",j._indirectTexture,A),Rt.setOptional(U,j,"batchingColorTexture"),j._colorsTexture!==null&&Rt.setValue(U,"batchingColorTexture",j._colorsTexture,A));const Ar=oe.morphAttributes;if((Ar.position!==void 0||Ar.normal!==void 0||Ar.color!==void 0)&&Ve.update(j,oe,Yt),(an||Be.receiveShadow!==j.receiveShadow)&&(Be.receiveShadow=j.receiveShadow,Rt.setValue(U,"receiveShadow",j.receiveShadow)),ae.isMeshGouraudMaterial&&ae.envMap!==null&&(ci.envMap.value=He,ci.flipEnvMap.value=He.isCubeTexture&&He.isRenderTargetTexture===!1?-1:1),ae.isMeshStandardMaterial&&ae.envMap===null&&Y.environment!==null&&(ci.envMapIntensity.value=Y.environmentIntensity),an&&(Rt.setValue(U,"toneMappingExposure",_.toneMappingExposure),Be.needsLights&&ga(ci,hs),Ce&&ae.fog===!0&&ue.refreshFogUniforms(ci,Ce),ue.refreshMaterialUniforms(ci,ae,Z,k,p.state.transmissionRenderTarget[L.id]),hl.upload(U,ma(Be),ci,A)),ae.isShaderMaterial&&ae.uniformsNeedUpdate===!0&&(hl.upload(U,ma(Be),ci,A),ae.uniformsNeedUpdate=!1),ae.isSpriteMaterial&&Rt.setValue(U,"center",j.center),Rt.setValue(U,"modelViewMatrix",j.modelViewMatrix),Rt.setValue(U,"normalMatrix",j.normalMatrix),Rt.setValue(U,"modelMatrix",j.matrixWorld),ae.isShaderMaterial||ae.isRawShaderMaterial){const Mn=ae.uniformsGroups;for(let D=0,J=Mn.length;D<J;D++){const be=Mn[D];X.update(be,Yt),X.bind(be,Yt)}}return Yt}function ga(L,Y){L.ambientLightColor.needsUpdate=Y,L.lightProbe.needsUpdate=Y,L.directionalLights.needsUpdate=Y,L.directionalLightShadows.needsUpdate=Y,L.pointLights.needsUpdate=Y,L.pointLightShadows.needsUpdate=Y,L.spotLights.needsUpdate=Y,L.spotLightShadows.needsUpdate=Y,L.rectAreaLights.needsUpdate=Y,L.hemisphereLights.needsUpdate=Y}function Tr(L){return L.isMeshLambertMaterial||L.isMeshToonMaterial||L.isMeshPhongMaterial||L.isMeshStandardMaterial||L.isShadowMaterial||L.isShaderMaterial&&L.lights===!0}this.getActiveCubeFace=function(){return C},this.getActiveMipmapLevel=function(){return M},this.getRenderTarget=function(){return w},this.setRenderTargetTextures=function(L,Y,oe){V.get(L.texture).__webglTexture=Y,V.get(L.depthTexture).__webglTexture=oe;const ae=V.get(L);ae.__hasExternalTextures=!0,ae.__autoAllocateDepthBuffer=oe===void 0,ae.__autoAllocateDepthBuffer||ye.has("WEBGL_multisampled_render_to_texture")===!0&&(console.warn("THREE.WebGLRenderer: Render-to-texture extension was disabled because an external texture was provided"),ae.__useRenderToTexture=!1)},this.setRenderTargetFramebuffer=function(L,Y){const oe=V.get(L);oe.__webglFramebuffer=Y,oe.__useDefaultFramebuffer=Y===void 0},this.setRenderTarget=function(L,Y=0,oe=0){w=L,C=Y,M=oe;let ae=!0,j=null,Ce=!1,Ue=!1;if(L){const He=V.get(L);if(He.__useDefaultFramebuffer!==void 0)B.bindFramebuffer(U.FRAMEBUFFER,null),ae=!1;else if(He.__webglFramebuffer===void 0)A.setupRenderTarget(L);else if(He.__hasExternalTextures)A.rebindTextures(L,V.get(L.texture).__webglTexture,V.get(L.depthTexture).__webglTexture);else if(L.depthBuffer){const Ge=L.depthTexture;if(He.__boundDepthTexture!==Ge){if(Ge!==null&&V.has(Ge)&&(L.width!==Ge.image.width||L.height!==Ge.image.height))throw new Error("WebGLRenderTarget: Attached DepthTexture is initialized to the incorrect size.");A.setupDepthRenderbuffer(L)}}const Ze=L.texture;(Ze.isData3DTexture||Ze.isDataArrayTexture||Ze.isCompressedArrayTexture)&&(Ue=!0);const $e=V.get(L).__webglFramebuffer;L.isWebGLCubeRenderTarget?(Array.isArray($e[Y])?j=$e[Y][oe]:j=$e[Y],Ce=!0):L.samples>0&&A.useMultisampledRTT(L)===!1?j=V.get(L).__webglMultisampledFramebuffer:Array.isArray($e)?j=$e[oe]:j=$e,S.copy(L.viewport),b.copy(L.scissor),N=L.scissorTest}else S.copy(ce).multiplyScalar(Z).floor(),b.copy(W).multiplyScalar(Z).floor(),N=re;if(B.bindFramebuffer(U.FRAMEBUFFER,j)&&ae&&B.drawBuffers(L,j),B.viewport(S),B.scissor(b),B.setScissorTest(N),Ce){const He=V.get(L.texture);U.framebufferTexture2D(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_CUBE_MAP_POSITIVE_X+Y,He.__webglTexture,oe)}else if(Ue){const He=V.get(L.texture),Ze=Y||0;U.framebufferTextureLayer(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0,He.__webglTexture,oe||0,Ze)}P=-1},this.readRenderTargetPixels=function(L,Y,oe,ae,j,Ce,Ue){if(!(L&&L.isWebGLRenderTarget)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let ke=V.get(L).__webglFramebuffer;if(L.isWebGLCubeRenderTarget&&Ue!==void 0&&(ke=ke[Ue]),ke){B.bindFramebuffer(U.FRAMEBUFFER,ke);try{const He=L.texture,Ze=He.format,$e=He.type;if(!ge.textureFormatReadable(Ze)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(!ge.textureTypeReadable($e)){console.error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}Y>=0&&Y<=L.width-ae&&oe>=0&&oe<=L.height-j&&U.readPixels(Y,oe,ae,j,We.convert(Ze),We.convert($e),Ce)}finally{const He=w!==null?V.get(w).__webglFramebuffer:null;B.bindFramebuffer(U.FRAMEBUFFER,He)}}},this.readRenderTargetPixelsAsync=async function(L,Y,oe,ae,j,Ce,Ue){if(!(L&&L.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let ke=V.get(L).__webglFramebuffer;if(L.isWebGLCubeRenderTarget&&Ue!==void 0&&(ke=ke[Ue]),ke){const He=L.texture,Ze=He.format,$e=He.type;if(!ge.textureFormatReadable(Ze))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(!ge.textureTypeReadable($e))throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");if(Y>=0&&Y<=L.width-ae&&oe>=0&&oe<=L.height-j){B.bindFramebuffer(U.FRAMEBUFFER,ke);const Ge=U.createBuffer();U.bindBuffer(U.PIXEL_PACK_BUFFER,Ge),U.bufferData(U.PIXEL_PACK_BUFFER,Ce.byteLength,U.STREAM_READ),U.readPixels(Y,oe,ae,j,We.convert(Ze),We.convert($e),0);const ct=w!==null?V.get(w).__webglFramebuffer:null;B.bindFramebuffer(U.FRAMEBUFFER,ct);const vt=U.fenceSync(U.SYNC_GPU_COMMANDS_COMPLETE,0);return U.flush(),await Og(U,vt,4),U.bindBuffer(U.PIXEL_PACK_BUFFER,Ge),U.getBufferSubData(U.PIXEL_PACK_BUFFER,0,Ce),U.deleteBuffer(Ge),U.deleteSync(vt),Ce}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")}},this.copyFramebufferToTexture=function(L,Y=null,oe=0){L.isTexture!==!0&&(ul("WebGLRenderer: copyFramebufferToTexture function signature has changed."),Y=arguments[0]||null,L=arguments[1]);const ae=Math.pow(2,-oe),j=Math.floor(L.image.width*ae),Ce=Math.floor(L.image.height*ae),Ue=Y!==null?Y.x:0,ke=Y!==null?Y.y:0;A.setTexture2D(L,0),U.copyTexSubImage2D(U.TEXTURE_2D,oe,0,0,Ue,ke,j,Ce),B.unbindTexture()},this.copyTextureToTexture=function(L,Y,oe=null,ae=null,j=0){L.isTexture!==!0&&(ul("WebGLRenderer: copyTextureToTexture function signature has changed."),ae=arguments[0]||null,L=arguments[1],Y=arguments[2],j=arguments[3]||0,oe=null);let Ce,Ue,ke,He,Ze,$e;oe!==null?(Ce=oe.max.x-oe.min.x,Ue=oe.max.y-oe.min.y,ke=oe.min.x,He=oe.min.y):(Ce=L.image.width,Ue=L.image.height,ke=0,He=0),ae!==null?(Ze=ae.x,$e=ae.y):(Ze=0,$e=0);const Ge=We.convert(Y.format),ct=We.convert(Y.type);A.setTexture2D(Y,0),U.pixelStorei(U.UNPACK_FLIP_Y_WEBGL,Y.flipY),U.pixelStorei(U.UNPACK_PREMULTIPLY_ALPHA_WEBGL,Y.premultiplyAlpha),U.pixelStorei(U.UNPACK_ALIGNMENT,Y.unpackAlignment);const vt=U.getParameter(U.UNPACK_ROW_LENGTH),Tt=U.getParameter(U.UNPACK_IMAGE_HEIGHT),gn=U.getParameter(U.UNPACK_SKIP_PIXELS),ut=U.getParameter(U.UNPACK_SKIP_ROWS),Be=U.getParameter(U.UNPACK_SKIP_IMAGES),Vt=L.isCompressedTexture?L.mipmaps[j]:L.image;U.pixelStorei(U.UNPACK_ROW_LENGTH,Vt.width),U.pixelStorei(U.UNPACK_IMAGE_HEIGHT,Vt.height),U.pixelStorei(U.UNPACK_SKIP_PIXELS,ke),U.pixelStorei(U.UNPACK_SKIP_ROWS,He),L.isDataTexture?U.texSubImage2D(U.TEXTURE_2D,j,Ze,$e,Ce,Ue,Ge,ct,Vt.data):L.isCompressedTexture?U.compressedTexSubImage2D(U.TEXTURE_2D,j,Ze,$e,Vt.width,Vt.height,Ge,Vt.data):U.texSubImage2D(U.TEXTURE_2D,j,Ze,$e,Ce,Ue,Ge,ct,Vt),U.pixelStorei(U.UNPACK_ROW_LENGTH,vt),U.pixelStorei(U.UNPACK_IMAGE_HEIGHT,Tt),U.pixelStorei(U.UNPACK_SKIP_PIXELS,gn),U.pixelStorei(U.UNPACK_SKIP_ROWS,ut),U.pixelStorei(U.UNPACK_SKIP_IMAGES,Be),j===0&&Y.generateMipmaps&&U.generateMipmap(U.TEXTURE_2D),B.unbindTexture()},this.copyTextureToTexture3D=function(L,Y,oe=null,ae=null,j=0){L.isTexture!==!0&&(ul("WebGLRenderer: copyTextureToTexture3D function signature has changed."),oe=arguments[0]||null,ae=arguments[1]||null,L=arguments[2],Y=arguments[3],j=arguments[4]||0);let Ce,Ue,ke,He,Ze,$e,Ge,ct,vt;const Tt=L.isCompressedTexture?L.mipmaps[j]:L.image;oe!==null?(Ce=oe.max.x-oe.min.x,Ue=oe.max.y-oe.min.y,ke=oe.max.z-oe.min.z,He=oe.min.x,Ze=oe.min.y,$e=oe.min.z):(Ce=Tt.width,Ue=Tt.height,ke=Tt.depth,He=0,Ze=0,$e=0),ae!==null?(Ge=ae.x,ct=ae.y,vt=ae.z):(Ge=0,ct=0,vt=0);const gn=We.convert(Y.format),ut=We.convert(Y.type);let Be;if(Y.isData3DTexture)A.setTexture3D(Y,0),Be=U.TEXTURE_3D;else if(Y.isDataArrayTexture||Y.isCompressedArrayTexture)A.setTexture2DArray(Y,0),Be=U.TEXTURE_2D_ARRAY;else{console.warn("THREE.WebGLRenderer.copyTextureToTexture3D: only supports THREE.DataTexture3D and THREE.DataTexture2DArray.");return}U.pixelStorei(U.UNPACK_FLIP_Y_WEBGL,Y.flipY),U.pixelStorei(U.UNPACK_PREMULTIPLY_ALPHA_WEBGL,Y.premultiplyAlpha),U.pixelStorei(U.UNPACK_ALIGNMENT,Y.unpackAlignment);const Vt=U.getParameter(U.UNPACK_ROW_LENGTH),ot=U.getParameter(U.UNPACK_IMAGE_HEIGHT),Yt=U.getParameter(U.UNPACK_SKIP_PIXELS),qi=U.getParameter(U.UNPACK_SKIP_ROWS),an=U.getParameter(U.UNPACK_SKIP_IMAGES);U.pixelStorei(U.UNPACK_ROW_LENGTH,Tt.width),U.pixelStorei(U.UNPACK_IMAGE_HEIGHT,Tt.height),U.pixelStorei(U.UNPACK_SKIP_PIXELS,He),U.pixelStorei(U.UNPACK_SKIP_ROWS,Ze),U.pixelStorei(U.UNPACK_SKIP_IMAGES,$e),L.isDataTexture||L.isData3DTexture?U.texSubImage3D(Be,j,Ge,ct,vt,Ce,Ue,ke,gn,ut,Tt.data):Y.isCompressedArrayTexture?U.compressedTexSubImage3D(Be,j,Ge,ct,vt,Ce,Ue,ke,gn,Tt.data):U.texSubImage3D(Be,j,Ge,ct,vt,Ce,Ue,ke,gn,ut,Tt),U.pixelStorei(U.UNPACK_ROW_LENGTH,Vt),U.pixelStorei(U.UNPACK_IMAGE_HEIGHT,ot),U.pixelStorei(U.UNPACK_SKIP_PIXELS,Yt),U.pixelStorei(U.UNPACK_SKIP_ROWS,qi),U.pixelStorei(U.UNPACK_SKIP_IMAGES,an),j===0&&Y.generateMipmaps&&U.generateMipmap(Be),B.unbindTexture()},this.initRenderTarget=function(L){V.get(L).__webglFramebuffer===void 0&&A.setupRenderTarget(L)},this.initTexture=function(L){L.isCubeTexture?A.setTextureCube(L,0):L.isData3DTexture?A.setTexture3D(L,0):L.isDataArrayTexture||L.isCompressedArrayTexture?A.setTexture2DArray(L,0):A.setTexture2D(L,0),B.unbindTexture()},this.resetState=function(){C=0,M=0,w=null,B.reset(),dt.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return Oi}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(e){this._outputColorSpace=e;const t=this.getContext();t.drawingBufferColorSpace=e===Ih?"display-p3":"srgb",t.unpackColorSpace=gt.workingColorSpace===Vl?"display-p3":"srgb"}}class Zu extends yn{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Mi,this.environmentIntensity=1,this.environmentRotation=new Mi,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(e,t){return super.copy(e,t),e.background!==null&&(this.background=e.background.clone()),e.environment!==null&&(this.environment=e.environment.clone()),e.fog!==null&&(this.fog=e.fog.clone()),this.backgroundBlurriness=e.backgroundBlurriness,this.backgroundIntensity=e.backgroundIntensity,this.backgroundRotation.copy(e.backgroundRotation),this.environmentIntensity=e.environmentIntensity,this.environmentRotation.copy(e.environmentRotation),e.overrideMaterial!==null&&(this.overrideMaterial=e.overrideMaterial.clone()),this.matrixAutoUpdate=e.matrixAutoUpdate,this}toJSON(e){const t=super.toJSON(e);return this.fog!==null&&(t.object.fog=this.fog.toJSON()),this.backgroundBlurriness>0&&(t.object.backgroundBlurriness=this.backgroundBlurriness),this.backgroundIntensity!==1&&(t.object.backgroundIntensity=this.backgroundIntensity),t.object.backgroundRotation=this.backgroundRotation.toArray(),this.environmentIntensity!==1&&(t.object.environmentIntensity=this.environmentIntensity),t.object.environmentRotation=this.environmentRotation.toArray(),t}}class Zy extends sn{constructor(e=null,t=1,i=1,r,s,o,a,l,c=dn,u=dn,h,f){super(null,o,a,l,c,u,r,s,h,f),this.isDataTexture=!0,this.image={data:e,width:t,height:i},this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}}class Ho extends kt{constructor(e,t,i,r=1){super(e,t,i),this.isInstancedBufferAttribute=!0,this.meshPerAttribute=r}copy(e){return super.copy(e),this.meshPerAttribute=e.meshPerAttribute,this}toJSON(){const e=super.toJSON();return e.meshPerAttribute=this.meshPerAttribute,e.isInstancedBufferAttribute=!0,e}}class Jy extends os{constructor(e){super(),this.isPointsMaterial=!0,this.type="PointsMaterial",this.color=new st(16777215),this.map=null,this.alphaMap=null,this.size=1,this.sizeAttenuation=!0,this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.alphaMap=e.alphaMap,this.size=e.size,this.sizeAttenuation=e.sizeAttenuation,this.fog=e.fog,this}}const vd=new It,Ju=new X0,ka=new Wl,Ba=new O;class Yl extends yn{constructor(e=new Et,t=new Jy){super(),this.isPoints=!0,this.type="Points",this.geometry=e,this.material=t,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}raycast(e,t){const i=this.geometry,r=this.matrixWorld,s=e.params.Points.threshold,o=i.drawRange;if(i.boundingSphere===null&&i.computeBoundingSphere(),ka.copy(i.boundingSphere),ka.applyMatrix4(r),ka.radius+=s,e.ray.intersectsSphere(ka)===!1)return;vd.copy(r).invert(),Ju.copy(e.ray).applyMatrix4(vd);const a=s/((this.scale.x+this.scale.y+this.scale.z)/3),l=a*a,c=i.index,h=i.attributes.position;if(c!==null){const f=Math.max(0,o.start),d=Math.min(c.count,o.start+o.count);for(let v=f,g=d;v<g;v++){const p=c.getX(v);Ba.fromBufferAttribute(h,p),_d(Ba,p,l,r,e,t,this)}}else{const f=Math.max(0,o.start),d=Math.min(h.count,o.start+o.count);for(let v=f,g=d;v<g;v++)Ba.fromBufferAttribute(h,v),_d(Ba,v,l,r,e,t,this)}}updateMorphTargets(){const t=this.geometry.morphAttributes,i=Object.keys(t);if(i.length>0){const r=t[i[0]];if(r!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let s=0,o=r.length;s<o;s++){const a=r[s].name||String(s);this.morphTargetInfluences.push(0),this.morphTargetDictionary[a]=s}}}}}function _d(n,e,t,i,r,s,o){const a=Ju.distanceSqToPoint(n);if(a<t){const l=new O;Ju.closestPointToPoint(n,l),l.applyMatrix4(i);const c=r.ray.origin.distanceTo(l);if(c<r.near||c>r.far)return;s.push({distance:c,distanceToRay:Math.sqrt(a),point:l,index:e,face:null,faceIndex:null,barycoord:null,object:o})}}class Ei{constructor(){this.type="Curve",this.arcLengthDivisions=200}getPoint(){return console.warn("THREE.Curve: .getPoint() not implemented."),null}getPointAt(e,t){const i=this.getUtoTmapping(e);return this.getPoint(i,t)}getPoints(e=5){const t=[];for(let i=0;i<=e;i++)t.push(this.getPoint(i/e));return t}getSpacedPoints(e=5){const t=[];for(let i=0;i<=e;i++)t.push(this.getPointAt(i/e));return t}getLength(){const e=this.getLengths();return e[e.length-1]}getLengths(e=this.arcLengthDivisions){if(this.cacheArcLengths&&this.cacheArcLengths.length===e+1&&!this.needsUpdate)return this.cacheArcLengths;this.needsUpdate=!1;const t=[];let i,r=this.getPoint(0),s=0;t.push(0);for(let o=1;o<=e;o++)i=this.getPoint(o/e),s+=i.distanceTo(r),t.push(s),r=i;return this.cacheArcLengths=t,t}updateArcLengths(){this.needsUpdate=!0,this.getLengths()}getUtoTmapping(e,t){const i=this.getLengths();let r=0;const s=i.length;let o;t?o=t:o=e*i[s-1];let a=0,l=s-1,c;for(;a<=l;)if(r=Math.floor(a+(l-a)/2),c=i[r]-o,c<0)a=r+1;else if(c>0)l=r-1;else{l=r;break}if(r=l,i[r]===o)return r/(s-1);const u=i[r],f=i[r+1]-u,d=(o-u)/f;return(r+d)/(s-1)}getTangent(e,t){let r=e-1e-4,s=e+1e-4;r<0&&(r=0),s>1&&(s=1);const o=this.getPoint(r),a=this.getPoint(s),l=t||(o.isVector2?new we:new O);return l.copy(a).sub(o).normalize(),l}getTangentAt(e,t){const i=this.getUtoTmapping(e);return this.getTangent(i,t)}computeFrenetFrames(e,t){const i=new O,r=[],s=[],o=[],a=new O,l=new It;for(let d=0;d<=e;d++){const v=d/e;r[d]=this.getTangentAt(v,new O)}s[0]=new O,o[0]=new O;let c=Number.MAX_VALUE;const u=Math.abs(r[0].x),h=Math.abs(r[0].y),f=Math.abs(r[0].z);u<=c&&(c=u,i.set(1,0,0)),h<=c&&(c=h,i.set(0,1,0)),f<=c&&i.set(0,0,1),a.crossVectors(r[0],i).normalize(),s[0].crossVectors(r[0],a),o[0].crossVectors(r[0],s[0]);for(let d=1;d<=e;d++){if(s[d]=s[d-1].clone(),o[d]=o[d-1].clone(),a.crossVectors(r[d-1],r[d]),a.length()>Number.EPSILON){a.normalize();const v=Math.acos(tn(r[d-1].dot(r[d]),-1,1));s[d].applyMatrix4(l.makeRotationAxis(a,v))}o[d].crossVectors(r[d],s[d])}if(t===!0){let d=Math.acos(tn(s[0].dot(s[e]),-1,1));d/=e,r[0].dot(a.crossVectors(s[0],s[e]))>0&&(d=-d);for(let v=1;v<=e;v++)s[v].applyMatrix4(l.makeRotationAxis(r[v],d*v)),o[v].crossVectors(r[v],s[v])}return{tangents:r,normals:s,binormals:o}}clone(){return new this.constructor().copy(this)}copy(e){return this.arcLengthDivisions=e.arcLengthDivisions,this}toJSON(){const e={metadata:{version:4.6,type:"Curve",generator:"Curve.toJSON"}};return e.arcLengthDivisions=this.arcLengthDivisions,e.type=this.type,e}fromJSON(e){return this.arcLengthDivisions=e.arcLengthDivisions,this}}class kh extends Ei{constructor(e=0,t=0,i=1,r=1,s=0,o=Math.PI*2,a=!1,l=0){super(),this.isEllipseCurve=!0,this.type="EllipseCurve",this.aX=e,this.aY=t,this.xRadius=i,this.yRadius=r,this.aStartAngle=s,this.aEndAngle=o,this.aClockwise=a,this.aRotation=l}getPoint(e,t=new we){const i=t,r=Math.PI*2;let s=this.aEndAngle-this.aStartAngle;const o=Math.abs(s)<Number.EPSILON;for(;s<0;)s+=r;for(;s>r;)s-=r;s<Number.EPSILON&&(o?s=0:s=r),this.aClockwise===!0&&!o&&(s===r?s=-r:s=s-r);const a=this.aStartAngle+e*s;let l=this.aX+this.xRadius*Math.cos(a),c=this.aY+this.yRadius*Math.sin(a);if(this.aRotation!==0){const u=Math.cos(this.aRotation),h=Math.sin(this.aRotation),f=l-this.aX,d=c-this.aY;l=f*u-d*h+this.aX,c=f*h+d*u+this.aY}return i.set(l,c)}copy(e){return super.copy(e),this.aX=e.aX,this.aY=e.aY,this.xRadius=e.xRadius,this.yRadius=e.yRadius,this.aStartAngle=e.aStartAngle,this.aEndAngle=e.aEndAngle,this.aClockwise=e.aClockwise,this.aRotation=e.aRotation,this}toJSON(){const e=super.toJSON();return e.aX=this.aX,e.aY=this.aY,e.xRadius=this.xRadius,e.yRadius=this.yRadius,e.aStartAngle=this.aStartAngle,e.aEndAngle=this.aEndAngle,e.aClockwise=this.aClockwise,e.aRotation=this.aRotation,e}fromJSON(e){return super.fromJSON(e),this.aX=e.aX,this.aY=e.aY,this.xRadius=e.xRadius,this.yRadius=e.yRadius,this.aStartAngle=e.aStartAngle,this.aEndAngle=e.aEndAngle,this.aClockwise=e.aClockwise,this.aRotation=e.aRotation,this}}class Qy extends kh{constructor(e,t,i,r,s,o){super(e,t,i,i,r,s,o),this.isArcCurve=!0,this.type="ArcCurve"}}function Bh(){let n=0,e=0,t=0,i=0;function r(s,o,a,l){n=s,e=a,t=-3*s+3*o-2*a-l,i=2*s-2*o+a+l}return{initCatmullRom:function(s,o,a,l,c){r(o,a,c*(a-s),c*(l-o))},initNonuniformCatmullRom:function(s,o,a,l,c,u,h){let f=(o-s)/c-(a-s)/(c+u)+(a-o)/u,d=(a-o)/u-(l-o)/(u+h)+(l-a)/h;f*=u,d*=u,r(o,a,f,d)},calc:function(s){const o=s*s,a=o*s;return n+e*s+t*o+i*a}}}const za=new O,Dc=new Bh,Ic=new Bh,Uc=new Bh;class ip extends Ei{constructor(e=[],t=!1,i="centripetal",r=.5){super(),this.isCatmullRomCurve3=!0,this.type="CatmullRomCurve3",this.points=e,this.closed=t,this.curveType=i,this.tension=r}getPoint(e,t=new O){const i=t,r=this.points,s=r.length,o=(s-(this.closed?0:1))*e;let a=Math.floor(o),l=o-a;this.closed?a+=a>0?0:(Math.floor(Math.abs(a)/s)+1)*s:l===0&&a===s-1&&(a=s-2,l=1);let c,u;this.closed||a>0?c=r[(a-1)%s]:(za.subVectors(r[0],r[1]).add(r[0]),c=za);const h=r[a%s],f=r[(a+1)%s];if(this.closed||a+2<s?u=r[(a+2)%s]:(za.subVectors(r[s-1],r[s-2]).add(r[s-1]),u=za),this.curveType==="centripetal"||this.curveType==="chordal"){const d=this.curveType==="chordal"?.5:.25;let v=Math.pow(c.distanceToSquared(h),d),g=Math.pow(h.distanceToSquared(f),d),p=Math.pow(f.distanceToSquared(u),d);g<1e-4&&(g=1),v<1e-4&&(v=g),p<1e-4&&(p=g),Dc.initNonuniformCatmullRom(c.x,h.x,f.x,u.x,v,g,p),Ic.initNonuniformCatmullRom(c.y,h.y,f.y,u.y,v,g,p),Uc.initNonuniformCatmullRom(c.z,h.z,f.z,u.z,v,g,p)}else this.curveType==="catmullrom"&&(Dc.initCatmullRom(c.x,h.x,f.x,u.x,this.tension),Ic.initCatmullRom(c.y,h.y,f.y,u.y,this.tension),Uc.initCatmullRom(c.z,h.z,f.z,u.z,this.tension));return i.set(Dc.calc(l),Ic.calc(l),Uc.calc(l)),i}copy(e){super.copy(e),this.points=[];for(let t=0,i=e.points.length;t<i;t++){const r=e.points[t];this.points.push(r.clone())}return this.closed=e.closed,this.curveType=e.curveType,this.tension=e.tension,this}toJSON(){const e=super.toJSON();e.points=[];for(let t=0,i=this.points.length;t<i;t++){const r=this.points[t];e.points.push(r.toArray())}return e.closed=this.closed,e.curveType=this.curveType,e.tension=this.tension,e}fromJSON(e){super.fromJSON(e),this.points=[];for(let t=0,i=e.points.length;t<i;t++){const r=e.points[t];this.points.push(new O().fromArray(r))}return this.closed=e.closed,this.curveType=e.curveType,this.tension=e.tension,this}}function xd(n,e,t,i,r){const s=(i-e)*.5,o=(r-t)*.5,a=n*n,l=n*a;return(2*t-2*i+s+o)*l+(-3*t+3*i-2*s-o)*a+s*n+t}function e2(n,e){const t=1-n;return t*t*e}function t2(n,e){return 2*(1-n)*n*e}function n2(n,e){return n*n*e}function Go(n,e,t,i){return e2(n,e)+t2(n,t)+n2(n,i)}function i2(n,e){const t=1-n;return t*t*t*e}function r2(n,e){const t=1-n;return 3*t*t*n*e}function s2(n,e){return 3*(1-n)*n*n*e}function o2(n,e){return n*n*n*e}function Vo(n,e,t,i,r){return i2(n,e)+r2(n,t)+s2(n,i)+o2(n,r)}class rp extends Ei{constructor(e=new we,t=new we,i=new we,r=new we){super(),this.isCubicBezierCurve=!0,this.type="CubicBezierCurve",this.v0=e,this.v1=t,this.v2=i,this.v3=r}getPoint(e,t=new we){const i=t,r=this.v0,s=this.v1,o=this.v2,a=this.v3;return i.set(Vo(e,r.x,s.x,o.x,a.x),Vo(e,r.y,s.y,o.y,a.y)),i}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this.v3.copy(e.v3),this}toJSON(){const e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e.v3=this.v3.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this.v3.fromArray(e.v3),this}}class a2 extends Ei{constructor(e=new O,t=new O,i=new O,r=new O){super(),this.isCubicBezierCurve3=!0,this.type="CubicBezierCurve3",this.v0=e,this.v1=t,this.v2=i,this.v3=r}getPoint(e,t=new O){const i=t,r=this.v0,s=this.v1,o=this.v2,a=this.v3;return i.set(Vo(e,r.x,s.x,o.x,a.x),Vo(e,r.y,s.y,o.y,a.y),Vo(e,r.z,s.z,o.z,a.z)),i}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this.v3.copy(e.v3),this}toJSON(){const e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e.v3=this.v3.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this.v3.fromArray(e.v3),this}}class sp extends Ei{constructor(e=new we,t=new we){super(),this.isLineCurve=!0,this.type="LineCurve",this.v1=e,this.v2=t}getPoint(e,t=new we){const i=t;return e===1?i.copy(this.v2):(i.copy(this.v2).sub(this.v1),i.multiplyScalar(e).add(this.v1)),i}getPointAt(e,t){return this.getPoint(e,t)}getTangent(e,t=new we){return t.subVectors(this.v2,this.v1).normalize()}getTangentAt(e,t){return this.getTangent(e,t)}copy(e){return super.copy(e),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){const e=super.toJSON();return e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}}class l2 extends Ei{constructor(e=new O,t=new O){super(),this.isLineCurve3=!0,this.type="LineCurve3",this.v1=e,this.v2=t}getPoint(e,t=new O){const i=t;return e===1?i.copy(this.v2):(i.copy(this.v2).sub(this.v1),i.multiplyScalar(e).add(this.v1)),i}getPointAt(e,t){return this.getPoint(e,t)}getTangent(e,t=new O){return t.subVectors(this.v2,this.v1).normalize()}getTangentAt(e,t){return this.getTangent(e,t)}copy(e){return super.copy(e),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){const e=super.toJSON();return e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}}class op extends Ei{constructor(e=new we,t=new we,i=new we){super(),this.isQuadraticBezierCurve=!0,this.type="QuadraticBezierCurve",this.v0=e,this.v1=t,this.v2=i}getPoint(e,t=new we){const i=t,r=this.v0,s=this.v1,o=this.v2;return i.set(Go(e,r.x,s.x,o.x),Go(e,r.y,s.y,o.y)),i}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){const e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}}class c2 extends Ei{constructor(e=new O,t=new O,i=new O){super(),this.isQuadraticBezierCurve3=!0,this.type="QuadraticBezierCurve3",this.v0=e,this.v1=t,this.v2=i}getPoint(e,t=new O){const i=t,r=this.v0,s=this.v1,o=this.v2;return i.set(Go(e,r.x,s.x,o.x),Go(e,r.y,s.y,o.y),Go(e,r.z,s.z,o.z)),i}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){const e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}}class ap extends Ei{constructor(e=[]){super(),this.isSplineCurve=!0,this.type="SplineCurve",this.points=e}getPoint(e,t=new we){const i=t,r=this.points,s=(r.length-1)*e,o=Math.floor(s),a=s-o,l=r[o===0?o:o-1],c=r[o],u=r[o>r.length-2?r.length-1:o+1],h=r[o>r.length-3?r.length-1:o+2];return i.set(xd(a,l.x,c.x,u.x,h.x),xd(a,l.y,c.y,u.y,h.y)),i}copy(e){super.copy(e),this.points=[];for(let t=0,i=e.points.length;t<i;t++){const r=e.points[t];this.points.push(r.clone())}return this}toJSON(){const e=super.toJSON();e.points=[];for(let t=0,i=this.points.length;t<i;t++){const r=this.points[t];e.points.push(r.toArray())}return e}fromJSON(e){super.fromJSON(e),this.points=[];for(let t=0,i=e.points.length;t<i;t++){const r=e.points[t];this.points.push(new we().fromArray(r))}return this}}var Qu=Object.freeze({__proto__:null,ArcCurve:Qy,CatmullRomCurve3:ip,CubicBezierCurve:rp,CubicBezierCurve3:a2,EllipseCurve:kh,LineCurve:sp,LineCurve3:l2,QuadraticBezierCurve:op,QuadraticBezierCurve3:c2,SplineCurve:ap});class u2 extends Ei{constructor(){super(),this.type="CurvePath",this.curves=[],this.autoClose=!1}add(e){this.curves.push(e)}closePath(){const e=this.curves[0].getPoint(0),t=this.curves[this.curves.length-1].getPoint(1);if(!e.equals(t)){const i=e.isVector2===!0?"LineCurve":"LineCurve3";this.curves.push(new Qu[i](t,e))}return this}getPoint(e,t){const i=e*this.getLength(),r=this.getCurveLengths();let s=0;for(;s<r.length;){if(r[s]>=i){const o=r[s]-i,a=this.curves[s],l=a.getLength(),c=l===0?0:1-o/l;return a.getPointAt(c,t)}s++}return null}getLength(){const e=this.getCurveLengths();return e[e.length-1]}updateArcLengths(){this.needsUpdate=!0,this.cacheLengths=null,this.getCurveLengths()}getCurveLengths(){if(this.cacheLengths&&this.cacheLengths.length===this.curves.length)return this.cacheLengths;const e=[];let t=0;for(let i=0,r=this.curves.length;i<r;i++)t+=this.curves[i].getLength(),e.push(t);return this.cacheLengths=e,e}getSpacedPoints(e=40){const t=[];for(let i=0;i<=e;i++)t.push(this.getPoint(i/e));return this.autoClose&&t.push(t[0]),t}getPoints(e=12){const t=[];let i;for(let r=0,s=this.curves;r<s.length;r++){const o=s[r],a=o.isEllipseCurve?e*2:o.isLineCurve||o.isLineCurve3?1:o.isSplineCurve?e*o.points.length:e,l=o.getPoints(a);for(let c=0;c<l.length;c++){const u=l[c];i&&i.equals(u)||(t.push(u),i=u)}}return this.autoClose&&t.length>1&&!t[t.length-1].equals(t[0])&&t.push(t[0]),t}copy(e){super.copy(e),this.curves=[];for(let t=0,i=e.curves.length;t<i;t++){const r=e.curves[t];this.curves.push(r.clone())}return this.autoClose=e.autoClose,this}toJSON(){const e=super.toJSON();e.autoClose=this.autoClose,e.curves=[];for(let t=0,i=this.curves.length;t<i;t++){const r=this.curves[t];e.curves.push(r.toJSON())}return e}fromJSON(e){super.fromJSON(e),this.autoClose=e.autoClose,this.curves=[];for(let t=0,i=e.curves.length;t<i;t++){const r=e.curves[t];this.curves.push(new Qu[r.type]().fromJSON(r))}return this}}class yd extends u2{constructor(e){super(),this.type="Path",this.currentPoint=new we,e&&this.setFromPoints(e)}setFromPoints(e){this.moveTo(e[0].x,e[0].y);for(let t=1,i=e.length;t<i;t++)this.lineTo(e[t].x,e[t].y);return this}moveTo(e,t){return this.currentPoint.set(e,t),this}lineTo(e,t){const i=new sp(this.currentPoint.clone(),new we(e,t));return this.curves.push(i),this.currentPoint.set(e,t),this}quadraticCurveTo(e,t,i,r){const s=new op(this.currentPoint.clone(),new we(e,t),new we(i,r));return this.curves.push(s),this.currentPoint.set(i,r),this}bezierCurveTo(e,t,i,r,s,o){const a=new rp(this.currentPoint.clone(),new we(e,t),new we(i,r),new we(s,o));return this.curves.push(a),this.currentPoint.set(s,o),this}splineThru(e){const t=[this.currentPoint.clone()].concat(e),i=new ap(t);return this.curves.push(i),this.currentPoint.copy(e[e.length-1]),this}arc(e,t,i,r,s,o){const a=this.currentPoint.x,l=this.currentPoint.y;return this.absarc(e+a,t+l,i,r,s,o),this}absarc(e,t,i,r,s,o){return this.absellipse(e,t,i,i,r,s,o),this}ellipse(e,t,i,r,s,o,a,l){const c=this.currentPoint.x,u=this.currentPoint.y;return this.absellipse(e+c,t+u,i,r,s,o,a,l),this}absellipse(e,t,i,r,s,o,a,l){const c=new kh(e,t,i,r,s,o,a,l);if(this.curves.length>0){const h=c.getPoint(0);h.equals(this.currentPoint)||this.lineTo(h.x,h.y)}this.curves.push(c);const u=c.getPoint(1);return this.currentPoint.copy(u),this}copy(e){return super.copy(e),this.currentPoint.copy(e.currentPoint),this}toJSON(){const e=super.toJSON();return e.currentPoint=this.currentPoint.toArray(),e}fromJSON(e){return super.fromJSON(e),this.currentPoint.fromArray(e.currentPoint),this}}class zh extends Et{constructor(e=[new we(0,-.5),new we(.5,0),new we(0,.5)],t=12,i=0,r=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:e,segments:t,phiStart:i,phiLength:r},t=Math.floor(t),r=tn(r,0,Math.PI*2);const s=[],o=[],a=[],l=[],c=[],u=1/t,h=new O,f=new we,d=new O,v=new O,g=new O;let p=0,m=0;for(let x=0;x<=e.length-1;x++)switch(x){case 0:p=e[x+1].x-e[x].x,m=e[x+1].y-e[x].y,d.x=m*1,d.y=-p,d.z=m*0,g.copy(d),d.normalize(),l.push(d.x,d.y,d.z);break;case e.length-1:l.push(g.x,g.y,g.z);break;default:p=e[x+1].x-e[x].x,m=e[x+1].y-e[x].y,d.x=m*1,d.y=-p,d.z=m*0,v.copy(d),d.x+=g.x,d.y+=g.y,d.z+=g.z,d.normalize(),l.push(d.x,d.y,d.z),g.copy(v)}for(let x=0;x<=t;x++){const _=i+x*u*r,y=Math.sin(_),C=Math.cos(_);for(let M=0;M<=e.length-1;M++){h.x=e[M].x*y,h.y=e[M].y,h.z=e[M].x*C,o.push(h.x,h.y,h.z),f.x=x/t,f.y=M/(e.length-1),a.push(f.x,f.y);const w=l[3*M+0]*y,P=l[3*M+1],I=l[3*M+0]*C;c.push(w,P,I)}}for(let x=0;x<t;x++)for(let _=0;_<e.length-1;_++){const y=_+x*e.length,C=y,M=y+e.length,w=y+e.length+1,P=y+1;s.push(C,M,P),s.push(w,P,M)}this.setIndex(s),this.setAttribute("position",new nt(o,3)),this.setAttribute("uv",new nt(a,2)),this.setAttribute("normal",new nt(c,3))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new zh(e.points,e.segments,e.phiStart,e.phiLength)}}class da extends Et{constructor(e=1,t=32,i=0,r=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:e,segments:t,thetaStart:i,thetaLength:r},t=Math.max(3,t);const s=[],o=[],a=[],l=[],c=new O,u=new we;o.push(0,0,0),a.push(0,0,1),l.push(.5,.5);for(let h=0,f=3;h<=t;h++,f+=3){const d=i+h/t*r;c.x=e*Math.cos(d),c.y=e*Math.sin(d),o.push(c.x,c.y,c.z),a.push(0,0,1),u.x=(o[f]/e+1)/2,u.y=(o[f+1]/e+1)/2,l.push(u.x,u.y)}for(let h=1;h<=t;h++)s.push(h,h+1,0);this.setIndex(s),this.setAttribute("position",new nt(o,3)),this.setAttribute("normal",new nt(a,3)),this.setAttribute("uv",new nt(l,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new da(e.radius,e.segments,e.thetaStart,e.thetaLength)}}class Hh extends Et{constructor(e=1,t=1,i=1,r=32,s=1,o=!1,a=0,l=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:e,radiusBottom:t,height:i,radialSegments:r,heightSegments:s,openEnded:o,thetaStart:a,thetaLength:l};const c=this;r=Math.floor(r),s=Math.floor(s);const u=[],h=[],f=[],d=[];let v=0;const g=[],p=i/2;let m=0;x(),o===!1&&(e>0&&_(!0),t>0&&_(!1)),this.setIndex(u),this.setAttribute("position",new nt(h,3)),this.setAttribute("normal",new nt(f,3)),this.setAttribute("uv",new nt(d,2));function x(){const y=new O,C=new O;let M=0;const w=(t-e)/i;for(let P=0;P<=s;P++){const I=[],S=P/s,b=S*(t-e)+e;for(let N=0;N<=r;N++){const R=N/r,H=R*l+a,T=Math.sin(H),k=Math.cos(H);C.x=b*T,C.y=-S*i+p,C.z=b*k,h.push(C.x,C.y,C.z),y.set(T,w,k).normalize(),f.push(y.x,y.y,y.z),d.push(R,1-S),I.push(v++)}g.push(I)}for(let P=0;P<r;P++)for(let I=0;I<s;I++){const S=g[I][P],b=g[I+1][P],N=g[I+1][P+1],R=g[I][P+1];e>0&&(u.push(S,b,R),M+=3),t>0&&(u.push(b,N,R),M+=3)}c.addGroup(m,M,0),m+=M}function _(y){const C=v,M=new we,w=new O;let P=0;const I=y===!0?e:t,S=y===!0?1:-1;for(let N=1;N<=r;N++)h.push(0,p*S,0),f.push(0,S,0),d.push(.5,.5),v++;const b=v;for(let N=0;N<=r;N++){const H=N/r*l+a,T=Math.cos(H),k=Math.sin(H);w.x=I*k,w.y=p*S,w.z=I*T,h.push(w.x,w.y,w.z),f.push(0,S,0),M.x=T*.5+.5,M.y=k*.5*S+.5,d.push(M.x,M.y),v++}for(let N=0;N<r;N++){const R=C+N,H=b+N;y===!0?u.push(H,H+1,R):u.push(H+1,H,R),P+=3}c.addGroup(m,P,y===!0?1:2),m+=P}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new Hh(e.radiusTop,e.radiusBottom,e.height,e.radialSegments,e.heightSegments,e.openEnded,e.thetaStart,e.thetaLength)}}const Ha=new O,Ga=new O,Nc=new O,Va=new Bn;class h2 extends Et{constructor(e=null,t=1){if(super(),this.type="EdgesGeometry",this.parameters={geometry:e,thresholdAngle:t},e!==null){const r=Math.pow(10,4),s=Math.cos(qs*t),o=e.getIndex(),a=e.getAttribute("position"),l=o?o.count:a.count,c=[0,0,0],u=["a","b","c"],h=new Array(3),f={},d=[];for(let v=0;v<l;v+=3){o?(c[0]=o.getX(v),c[1]=o.getX(v+1),c[2]=o.getX(v+2)):(c[0]=v,c[1]=v+1,c[2]=v+2);const{a:g,b:p,c:m}=Va;if(g.fromBufferAttribute(a,c[0]),p.fromBufferAttribute(a,c[1]),m.fromBufferAttribute(a,c[2]),Va.getNormal(Nc),h[0]=`${Math.round(g.x*r)},${Math.round(g.y*r)},${Math.round(g.z*r)}`,h[1]=`${Math.round(p.x*r)},${Math.round(p.y*r)},${Math.round(p.z*r)}`,h[2]=`${Math.round(m.x*r)},${Math.round(m.y*r)},${Math.round(m.z*r)}`,!(h[0]===h[1]||h[1]===h[2]||h[2]===h[0]))for(let x=0;x<3;x++){const _=(x+1)%3,y=h[x],C=h[_],M=Va[u[x]],w=Va[u[_]],P=`${y}_${C}`,I=`${C}_${y}`;I in f&&f[I]?(Nc.dot(f[I].normal)<=s&&(d.push(M.x,M.y,M.z),d.push(w.x,w.y,w.z)),f[I]=null):P in f||(f[P]={index0:c[x],index1:c[_],normal:Nc.clone()})}}for(const v in f)if(f[v]){const{index0:g,index1:p}=f[v];Ha.fromBufferAttribute(a,g),Ga.fromBufferAttribute(a,p),d.push(Ha.x,Ha.y,Ha.z),d.push(Ga.x,Ga.y,Ga.z)}this.setAttribute("position",new nt(d,3))}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}}class no extends yd{constructor(e){super(e),this.uuid=ss(),this.type="Shape",this.holes=[]}getPointsHoles(e){const t=[];for(let i=0,r=this.holes.length;i<r;i++)t[i]=this.holes[i].getPoints(e);return t}extractPoints(e){return{shape:this.getPoints(e),holes:this.getPointsHoles(e)}}copy(e){super.copy(e),this.holes=[];for(let t=0,i=e.holes.length;t<i;t++){const r=e.holes[t];this.holes.push(r.clone())}return this}toJSON(){const e=super.toJSON();e.uuid=this.uuid,e.holes=[];for(let t=0,i=this.holes.length;t<i;t++){const r=this.holes[t];e.holes.push(r.toJSON())}return e}fromJSON(e){super.fromJSON(e),this.uuid=e.uuid,this.holes=[];for(let t=0,i=e.holes.length;t<i;t++){const r=e.holes[t];this.holes.push(new yd().fromJSON(r))}return this}}const f2={triangulate:function(n,e,t=2){const i=e&&e.length,r=i?e[0]*t:n.length;let s=lp(n,0,r,t,!0);const o=[];if(!s||s.next===s.prev)return o;let a,l,c,u,h,f,d;if(i&&(s=v2(n,e,s,t)),n.length>80*t){a=c=n[0],l=u=n[1];for(let v=t;v<r;v+=t)h=n[v],f=n[v+1],h<a&&(a=h),f<l&&(l=f),h>c&&(c=h),f>u&&(u=f);d=Math.max(c-a,u-l),d=d!==0?32767/d:0}return Jo(s,o,t,a,l,d,0),o}};function lp(n,e,t,i,r){let s,o;if(r===C2(n,e,t,i)>0)for(s=e;s<t;s+=i)o=Sd(s,n[s],n[s+1],o);else for(s=t-i;s>=e;s-=i)o=Sd(s,n[s],n[s+1],o);return o&&Kl(o,o.next)&&(ea(o),o=o.next),o}function es(n,e){if(!n)return n;e||(e=n);let t=n,i;do if(i=!1,!t.steiner&&(Kl(t,t.next)||Ft(t.prev,t,t.next)===0)){if(ea(t),t=e=t.prev,t===t.next)break;i=!0}else t=t.next;while(i||t!==e);return e}function Jo(n,e,t,i,r,s,o){if(!n)return;!o&&s&&M2(n,i,r,s);let a=n,l,c;for(;n.prev!==n.next;){if(l=n.prev,c=n.next,s?p2(n,i,r,s):d2(n)){e.push(l.i/t|0),e.push(n.i/t|0),e.push(c.i/t|0),ea(n),n=c.next,a=c.next;continue}if(n=c,n===a){o?o===1?(n=m2(es(n),e,t),Jo(n,e,t,i,r,s,2)):o===2&&g2(n,e,t,i,r,s):Jo(es(n),e,t,i,r,s,1);break}}}function d2(n){const e=n.prev,t=n,i=n.next;if(Ft(e,t,i)>=0)return!1;const r=e.x,s=t.x,o=i.x,a=e.y,l=t.y,c=i.y,u=r<s?r<o?r:o:s<o?s:o,h=a<l?a<c?a:c:l<c?l:c,f=r>s?r>o?r:o:s>o?s:o,d=a>l?a>c?a:c:l>c?l:c;let v=i.next;for(;v!==e;){if(v.x>=u&&v.x<=f&&v.y>=h&&v.y<=d&&ks(r,a,s,l,o,c,v.x,v.y)&&Ft(v.prev,v,v.next)>=0)return!1;v=v.next}return!0}function p2(n,e,t,i){const r=n.prev,s=n,o=n.next;if(Ft(r,s,o)>=0)return!1;const a=r.x,l=s.x,c=o.x,u=r.y,h=s.y,f=o.y,d=a<l?a<c?a:c:l<c?l:c,v=u<h?u<f?u:f:h<f?h:f,g=a>l?a>c?a:c:l>c?l:c,p=u>h?u>f?u:f:h>f?h:f,m=eh(d,v,e,t,i),x=eh(g,p,e,t,i);let _=n.prevZ,y=n.nextZ;for(;_&&_.z>=m&&y&&y.z<=x;){if(_.x>=d&&_.x<=g&&_.y>=v&&_.y<=p&&_!==r&&_!==o&&ks(a,u,l,h,c,f,_.x,_.y)&&Ft(_.prev,_,_.next)>=0||(_=_.prevZ,y.x>=d&&y.x<=g&&y.y>=v&&y.y<=p&&y!==r&&y!==o&&ks(a,u,l,h,c,f,y.x,y.y)&&Ft(y.prev,y,y.next)>=0))return!1;y=y.nextZ}for(;_&&_.z>=m;){if(_.x>=d&&_.x<=g&&_.y>=v&&_.y<=p&&_!==r&&_!==o&&ks(a,u,l,h,c,f,_.x,_.y)&&Ft(_.prev,_,_.next)>=0)return!1;_=_.prevZ}for(;y&&y.z<=x;){if(y.x>=d&&y.x<=g&&y.y>=v&&y.y<=p&&y!==r&&y!==o&&ks(a,u,l,h,c,f,y.x,y.y)&&Ft(y.prev,y,y.next)>=0)return!1;y=y.nextZ}return!0}function m2(n,e,t){let i=n;do{const r=i.prev,s=i.next.next;!Kl(r,s)&&cp(r,i,i.next,s)&&Qo(r,s)&&Qo(s,r)&&(e.push(r.i/t|0),e.push(i.i/t|0),e.push(s.i/t|0),ea(i),ea(i.next),i=n=s),i=i.next}while(i!==n);return es(i)}function g2(n,e,t,i,r,s){let o=n;do{let a=o.next.next;for(;a!==o.prev;){if(o.i!==a.i&&E2(o,a)){let l=up(o,a);o=es(o,o.next),l=es(l,l.next),Jo(o,e,t,i,r,s,0),Jo(l,e,t,i,r,s,0);return}a=a.next}o=o.next}while(o!==n)}function v2(n,e,t,i){const r=[];let s,o,a,l,c;for(s=0,o=e.length;s<o;s++)a=e[s]*i,l=s<o-1?e[s+1]*i:n.length,c=lp(n,a,l,i,!1),c===c.next&&(c.steiner=!0),r.push(w2(c));for(r.sort(_2),s=0;s<r.length;s++)t=x2(r[s],t);return t}function _2(n,e){return n.x-e.x}function x2(n,e){const t=y2(n,e);if(!t)return e;const i=up(t,n);return es(i,i.next),es(t,t.next)}function y2(n,e){let t=e,i=-1/0,r;const s=n.x,o=n.y;do{if(o<=t.y&&o>=t.next.y&&t.next.y!==t.y){const f=t.x+(o-t.y)*(t.next.x-t.x)/(t.next.y-t.y);if(f<=s&&f>i&&(i=f,r=t.x<t.next.x?t:t.next,f===s))return r}t=t.next}while(t!==e);if(!r)return null;const a=r,l=r.x,c=r.y;let u=1/0,h;t=r;do s>=t.x&&t.x>=l&&s!==t.x&&ks(o<c?s:i,o,l,c,o<c?i:s,o,t.x,t.y)&&(h=Math.abs(o-t.y)/(s-t.x),Qo(t,n)&&(h<u||h===u&&(t.x>r.x||t.x===r.x&&S2(r,t)))&&(r=t,u=h)),t=t.next;while(t!==a);return r}function S2(n,e){return Ft(n.prev,n,e.prev)<0&&Ft(e.next,n,n.next)<0}function M2(n,e,t,i){let r=n;do r.z===0&&(r.z=eh(r.x,r.y,e,t,i)),r.prevZ=r.prev,r.nextZ=r.next,r=r.next;while(r!==n);r.prevZ.nextZ=null,r.prevZ=null,b2(r)}function b2(n){let e,t,i,r,s,o,a,l,c=1;do{for(t=n,n=null,s=null,o=0;t;){for(o++,i=t,a=0,e=0;e<c&&(a++,i=i.nextZ,!!i);e++);for(l=c;a>0||l>0&&i;)a!==0&&(l===0||!i||t.z<=i.z)?(r=t,t=t.nextZ,a--):(r=i,i=i.nextZ,l--),s?s.nextZ=r:n=r,r.prevZ=s,s=r;t=i}s.nextZ=null,c*=2}while(o>1);return n}function eh(n,e,t,i,r){return n=(n-t)*r|0,e=(e-i)*r|0,n=(n|n<<8)&16711935,n=(n|n<<4)&252645135,n=(n|n<<2)&858993459,n=(n|n<<1)&1431655765,e=(e|e<<8)&16711935,e=(e|e<<4)&252645135,e=(e|e<<2)&858993459,e=(e|e<<1)&1431655765,n|e<<1}function w2(n){let e=n,t=n;do(e.x<t.x||e.x===t.x&&e.y<t.y)&&(t=e),e=e.next;while(e!==n);return t}function ks(n,e,t,i,r,s,o,a){return(r-o)*(e-a)>=(n-o)*(s-a)&&(n-o)*(i-a)>=(t-o)*(e-a)&&(t-o)*(s-a)>=(r-o)*(i-a)}function E2(n,e){return n.next.i!==e.i&&n.prev.i!==e.i&&!T2(n,e)&&(Qo(n,e)&&Qo(e,n)&&A2(n,e)&&(Ft(n.prev,n,e.prev)||Ft(n,e.prev,e))||Kl(n,e)&&Ft(n.prev,n,n.next)>0&&Ft(e.prev,e,e.next)>0)}function Ft(n,e,t){return(e.y-n.y)*(t.x-e.x)-(e.x-n.x)*(t.y-e.y)}function Kl(n,e){return n.x===e.x&&n.y===e.y}function cp(n,e,t,i){const r=Xa(Ft(n,e,t)),s=Xa(Ft(n,e,i)),o=Xa(Ft(t,i,n)),a=Xa(Ft(t,i,e));return!!(r!==s&&o!==a||r===0&&Wa(n,t,e)||s===0&&Wa(n,i,e)||o===0&&Wa(t,n,i)||a===0&&Wa(t,e,i))}function Wa(n,e,t){return e.x<=Math.max(n.x,t.x)&&e.x>=Math.min(n.x,t.x)&&e.y<=Math.max(n.y,t.y)&&e.y>=Math.min(n.y,t.y)}function Xa(n){return n>0?1:n<0?-1:0}function T2(n,e){let t=n;do{if(t.i!==n.i&&t.next.i!==n.i&&t.i!==e.i&&t.next.i!==e.i&&cp(t,t.next,n,e))return!0;t=t.next}while(t!==n);return!1}function Qo(n,e){return Ft(n.prev,n,n.next)<0?Ft(n,e,n.next)>=0&&Ft(n,n.prev,e)>=0:Ft(n,e,n.prev)<0||Ft(n,n.next,e)<0}function A2(n,e){let t=n,i=!1;const r=(n.x+e.x)/2,s=(n.y+e.y)/2;do t.y>s!=t.next.y>s&&t.next.y!==t.y&&r<(t.next.x-t.x)*(s-t.y)/(t.next.y-t.y)+t.x&&(i=!i),t=t.next;while(t!==n);return i}function up(n,e){const t=new th(n.i,n.x,n.y),i=new th(e.i,e.x,e.y),r=n.next,s=e.prev;return n.next=e,e.prev=n,t.next=r,r.prev=t,i.next=t,t.prev=i,s.next=i,i.prev=s,i}function Sd(n,e,t,i){const r=new th(n,e,t);return i?(r.next=i.next,r.prev=i,i.next.prev=r,i.next=r):(r.prev=r,r.next=r),r}function ea(n){n.next.prev=n.prev,n.prev.next=n.next,n.prevZ&&(n.prevZ.nextZ=n.nextZ),n.nextZ&&(n.nextZ.prevZ=n.prevZ)}function th(n,e,t){this.i=n,this.x=e,this.y=t,this.prev=null,this.next=null,this.z=0,this.prevZ=null,this.nextZ=null,this.steiner=!1}function C2(n,e,t,i){let r=0;for(let s=e,o=t-i;s<t;s+=i)r+=(n[o]-n[s])*(n[s+1]+n[o+1]),o=s;return r}class Wo{static area(e){const t=e.length;let i=0;for(let r=t-1,s=0;s<t;r=s++)i+=e[r].x*e[s].y-e[s].x*e[r].y;return i*.5}static isClockWise(e){return Wo.area(e)<0}static triangulateShape(e,t){const i=[],r=[],s=[];Md(e),bd(i,e);let o=e.length;t.forEach(Md);for(let l=0;l<t.length;l++)r.push(o),o+=t[l].length,bd(i,t[l]);const a=f2.triangulate(i,r);for(let l=0;l<a.length;l+=3)s.push(a.slice(l,l+3));return s}}function Md(n){const e=n.length;e>2&&n[e-1].equals(n[0])&&n.pop()}function bd(n,e){for(let t=0;t<e.length;t++)n.push(e[t].x),n.push(e[t].y)}class Gh extends Et{constructor(e=new no([new we(.5,.5),new we(-.5,.5),new we(-.5,-.5),new we(.5,-.5)]),t={}){super(),this.type="ExtrudeGeometry",this.parameters={shapes:e,options:t},e=Array.isArray(e)?e:[e];const i=this,r=[],s=[];for(let a=0,l=e.length;a<l;a++){const c=e[a];o(c)}this.setAttribute("position",new nt(r,3)),this.setAttribute("uv",new nt(s,2)),this.computeVertexNormals();function o(a){const l=[],c=t.curveSegments!==void 0?t.curveSegments:12,u=t.steps!==void 0?t.steps:1,h=t.depth!==void 0?t.depth:1;let f=t.bevelEnabled!==void 0?t.bevelEnabled:!0,d=t.bevelThickness!==void 0?t.bevelThickness:.2,v=t.bevelSize!==void 0?t.bevelSize:d-.1,g=t.bevelOffset!==void 0?t.bevelOffset:0,p=t.bevelSegments!==void 0?t.bevelSegments:3;const m=t.extrudePath,x=t.UVGenerator!==void 0?t.UVGenerator:R2;let _,y=!1,C,M,w,P;m&&(_=m.getSpacedPoints(u),y=!0,f=!1,C=m.computeFrenetFrames(u,!1),M=new O,w=new O,P=new O),f||(p=0,d=0,v=0,g=0);const I=a.extractPoints(c);let S=I.shape;const b=I.holes;if(!Wo.isClockWise(S)){S=S.reverse();for(let se=0,U=b.length;se<U;se++){const Se=b[se];Wo.isClockWise(Se)&&(b[se]=Se.reverse())}}const R=Wo.triangulateShape(S,b),H=S;for(let se=0,U=b.length;se<U;se++){const Se=b[se];S=S.concat(Se)}function T(se,U,Se){return U||console.error("THREE.ExtrudeGeometry: vec does not exist"),se.clone().addScaledVector(U,Se)}const k=S.length,Z=R.length;function K(se,U,Se){let ye,ge,B;const q=se.x-U.x,V=se.y-U.y,A=Se.x-se.x,E=Se.y-se.y,z=q*q+V*V,$=q*E-V*A;if(Math.abs($)>Number.EPSILON){const ne=Math.sqrt(z),te=Math.sqrt(A*A+E*E),ve=U.x-V/ne,ue=U.y+q/ne,Me=Se.x-E/te,Re=Se.y+A/te,de=((Me-ve)*E-(Re-ue)*A)/(q*E-V*A);ye=ve+q*de-se.x,ge=ue+V*de-se.y;const Ee=ye*ye+ge*ge;if(Ee<=2)return new we(ye,ge);B=Math.sqrt(Ee/2)}else{let ne=!1;q>Number.EPSILON?A>Number.EPSILON&&(ne=!0):q<-Number.EPSILON?A<-Number.EPSILON&&(ne=!0):Math.sign(V)===Math.sign(E)&&(ne=!0),ne?(ye=-V,ge=q,B=Math.sqrt(z)):(ye=q,ge=V,B=Math.sqrt(z/2))}return new we(ye/B,ge/B)}const pe=[];for(let se=0,U=H.length,Se=U-1,ye=se+1;se<U;se++,Se++,ye++)Se===U&&(Se=0),ye===U&&(ye=0),pe[se]=K(H[se],H[Se],H[ye]);const ce=[];let W,re=pe.concat();for(let se=0,U=b.length;se<U;se++){const Se=b[se];W=[];for(let ye=0,ge=Se.length,B=ge-1,q=ye+1;ye<ge;ye++,B++,q++)B===ge&&(B=0),q===ge&&(q=0),W[ye]=K(Se[ye],Se[B],Se[q]);ce.push(W),re=re.concat(W)}for(let se=0;se<p;se++){const U=se/p,Se=d*Math.cos(U*Math.PI/2),ye=v*Math.sin(U*Math.PI/2)+g;for(let ge=0,B=H.length;ge<B;ge++){const q=T(H[ge],pe[ge],ye);G(q.x,q.y,-Se)}for(let ge=0,B=b.length;ge<B;ge++){const q=b[ge];W=ce[ge];for(let V=0,A=q.length;V<A;V++){const E=T(q[V],W[V],ye);G(E.x,E.y,-Se)}}}const Ae=v+g;for(let se=0;se<k;se++){const U=f?T(S[se],re[se],Ae):S[se];y?(w.copy(C.normals[0]).multiplyScalar(U.x),M.copy(C.binormals[0]).multiplyScalar(U.y),P.copy(_[0]).add(w).add(M),G(P.x,P.y,P.z)):G(U.x,U.y,0)}for(let se=1;se<=u;se++)for(let U=0;U<k;U++){const Se=f?T(S[U],re[U],Ae):S[U];y?(w.copy(C.normals[se]).multiplyScalar(Se.x),M.copy(C.binormals[se]).multiplyScalar(Se.y),P.copy(_[se]).add(w).add(M),G(P.x,P.y,P.z)):G(Se.x,Se.y,h/u*se)}for(let se=p-1;se>=0;se--){const U=se/p,Se=d*Math.cos(U*Math.PI/2),ye=v*Math.sin(U*Math.PI/2)+g;for(let ge=0,B=H.length;ge<B;ge++){const q=T(H[ge],pe[ge],ye);G(q.x,q.y,h+Se)}for(let ge=0,B=b.length;ge<B;ge++){const q=b[ge];W=ce[ge];for(let V=0,A=q.length;V<A;V++){const E=T(q[V],W[V],ye);y?G(E.x,E.y+_[u-1].y,_[u-1].x+Se):G(E.x,E.y,h+Se)}}}ee(),F();function ee(){const se=r.length/3;if(f){let U=0,Se=k*U;for(let ye=0;ye<Z;ye++){const ge=R[ye];he(ge[2]+Se,ge[1]+Se,ge[0]+Se)}U=u+p*2,Se=k*U;for(let ye=0;ye<Z;ye++){const ge=R[ye];he(ge[0]+Se,ge[1]+Se,ge[2]+Se)}}else{for(let U=0;U<Z;U++){const Se=R[U];he(Se[2],Se[1],Se[0])}for(let U=0;U<Z;U++){const Se=R[U];he(Se[0]+k*u,Se[1]+k*u,Se[2]+k*u)}}i.addGroup(se,r.length/3-se,0)}function F(){const se=r.length/3;let U=0;xe(H,U),U+=H.length;for(let Se=0,ye=b.length;Se<ye;Se++){const ge=b[Se];xe(ge,U),U+=ge.length}i.addGroup(se,r.length/3-se,1)}function xe(se,U){let Se=se.length;for(;--Se>=0;){const ye=Se;let ge=Se-1;ge<0&&(ge=se.length-1);for(let B=0,q=u+p*2;B<q;B++){const V=k*B,A=k*(B+1),E=U+ye+V,z=U+ge+V,$=U+ge+A,ne=U+ye+A;me(E,z,$,ne)}}}function G(se,U,Se){l.push(se),l.push(U),l.push(Se)}function he(se,U,Se){fe(se),fe(U),fe(Se);const ye=r.length/3,ge=x.generateTopUV(i,r,ye-3,ye-2,ye-1);De(ge[0]),De(ge[1]),De(ge[2])}function me(se,U,Se,ye){fe(se),fe(U),fe(ye),fe(U),fe(Se),fe(ye);const ge=r.length/3,B=x.generateSideWallUV(i,r,ge-6,ge-3,ge-2,ge-1);De(B[0]),De(B[1]),De(B[3]),De(B[1]),De(B[2]),De(B[3])}function fe(se){r.push(l[se*3+0]),r.push(l[se*3+1]),r.push(l[se*3+2])}function De(se){s.push(se.x),s.push(se.y)}}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}toJSON(){const e=super.toJSON(),t=this.parameters.shapes,i=this.parameters.options;return P2(t,i,e)}static fromJSON(e,t){const i=[];for(let s=0,o=e.shapes.length;s<o;s++){const a=t[e.shapes[s]];i.push(a)}const r=e.options.extrudePath;return r!==void 0&&(e.options.extrudePath=new Qu[r.type]().fromJSON(r)),new Gh(i,e.options)}}const R2={generateTopUV:function(n,e,t,i,r){const s=e[t*3],o=e[t*3+1],a=e[i*3],l=e[i*3+1],c=e[r*3],u=e[r*3+1];return[new we(s,o),new we(a,l),new we(c,u)]},generateSideWallUV:function(n,e,t,i,r,s){const o=e[t*3],a=e[t*3+1],l=e[t*3+2],c=e[i*3],u=e[i*3+1],h=e[i*3+2],f=e[r*3],d=e[r*3+1],v=e[r*3+2],g=e[s*3],p=e[s*3+1],m=e[s*3+2];return Math.abs(a-u)<Math.abs(o-c)?[new we(o,1-l),new we(c,1-h),new we(f,1-v),new we(g,1-m)]:[new we(a,1-l),new we(u,1-h),new we(d,1-v),new we(p,1-m)]}};function P2(n,e,t){if(t.shapes=[],Array.isArray(n))for(let i=0,r=n.length;i<r;i++){const s=n[i];t.shapes.push(s.uuid)}else t.shapes.push(n.uuid);return t.options=Object.assign({},e),e.extrudePath!==void 0&&(t.options.extrudePath=e.extrudePath.toJSON()),t}class jl extends Et{constructor(e=1,t=32,i=16,r=0,s=Math.PI*2,o=0,a=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:e,widthSegments:t,heightSegments:i,phiStart:r,phiLength:s,thetaStart:o,thetaLength:a},t=Math.max(3,Math.floor(t)),i=Math.max(2,Math.floor(i));const l=Math.min(o+a,Math.PI);let c=0;const u=[],h=new O,f=new O,d=[],v=[],g=[],p=[];for(let m=0;m<=i;m++){const x=[],_=m/i;let y=0;m===0&&o===0?y=.5/t:m===i&&l===Math.PI&&(y=-.5/t);for(let C=0;C<=t;C++){const M=C/t;h.x=-e*Math.cos(r+M*s)*Math.sin(o+_*a),h.y=e*Math.cos(o+_*a),h.z=e*Math.sin(r+M*s)*Math.sin(o+_*a),v.push(h.x,h.y,h.z),f.copy(h).normalize(),g.push(f.x,f.y,f.z),p.push(M+y,1-_),x.push(c++)}u.push(x)}for(let m=0;m<i;m++)for(let x=0;x<t;x++){const _=u[m][x+1],y=u[m][x],C=u[m+1][x],M=u[m+1][x+1];(m!==0||o>0)&&d.push(_,y,M),(m!==i-1||l<Math.PI)&&d.push(y,C,M)}this.setIndex(d),this.setAttribute("position",new nt(v,3)),this.setAttribute("normal",new nt(g,3)),this.setAttribute("uv",new nt(p,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new jl(e.radius,e.widthSegments,e.heightSegments,e.phiStart,e.phiLength,e.thetaStart,e.thetaLength)}}class hp extends Et{constructor(){super(),this.isInstancedBufferGeometry=!0,this.type="InstancedBufferGeometry",this.instanceCount=1/0}copy(e){return super.copy(e),this.instanceCount=e.instanceCount,this}toJSON(){const e=super.toJSON();return e.instanceCount=this.instanceCount,e.isInstancedBufferGeometry=!0,e}}class it{constructor(e){this.value=e}clone(){return new it(this.value.clone===void 0?this.value:this.value.clone())}}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:ua}}));typeof window<"u"&&(window.__THREE__?console.warn("WARNING: Multiple instances of Three.js being imported."):window.__THREE__=ua);function L2(){const n=new Map;return{on(e,t){return n.has(e)||n.set(e,new Set),n.get(e).add(t),()=>n.get(e)?.delete(t)},off(e,t){n.get(e)?.delete(t)},once(e,t){const i=this.on(e,r=>{i(),t(r)});return i},emit(e,t){for(const i of[...n.get(e)||[]])try{i(t)}catch(r){console.error(`[bus] ${e} handler failed`,r)}}}}const Fc="https://equipseva.com",Xo="support@equipseva.com",Vh=(n,e=[])=>`mailto:${Xo}?subject=${encodeURIComponent(n)}`+(e.length?`&body=${encodeURIComponent(`${e.join(`\r
`)}\r
`)}`:""),fl=n=>Vh(n?`Service request: ${n}`:"Service request",["Hospital or clinic:","City:","Equipment brand and model:","Fault:","Phone:"]),D2=Vh("Engineer sign-up",["Name:","City:","Equipment you service:","Phone:"]),Wh=n=>Vh(n?`AMC enquiry: ${n}`:"AMC enquiry",["Hospital or clinic:","City:","Equipment and number of units:","Visit cadence you want:","Phone:"]),I2=Wh(),fp=`mailto:${Xo}`,Bs={label:"Join as an engineer",href:D2},qa={label:"Email us",href:fp},To=n=>[{label:"Request service",href:fl(n)},Bs],wd=[{label:"Privacy",href:`${Fc}/privacy/`},{label:"Terms",href:`${Fc}/terms/`},{label:"Refunds",href:`${Fc}/refunds/`}],U2=n=>`<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="${n}"/></svg>`,Ed={monitor:"M5 4.5h14a1.5 1.5 0 0 1 1.5 1.5v8.5a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5V6A1.5 1.5 0 0 1 5 4.5zM6.5 10.5h2.4l1.3-2.6 1.9 5 1.5-3.6 1 1.2h2.9M12 16v3.5M8.5 19.5h7",dental:"M12 5.3c-1.2-.9-2.4-1.6-4-1.6-2.6 0-4.3 2-4.3 4.8 0 2.1.8 3.6 1.5 5.4.7 1.8.9 3.8 1.4 5.6.3 1.1.8 1.6 1.4 1.6.8 0 1.2-.7 1.5-1.9l.8-3.2c.2-.9.8-1.4 1.7-1.4s1.5.5 1.7 1.4l.8 3.2c.3 1.2.7 1.9 1.5 1.9.6 0 1.1-.5 1.4-1.6.5-1.8.7-3.8 1.4-5.6.7-1.8 1.5-3.3 1.5-5.4 0-2.8-1.7-4.8-4.3-4.8-1.6 0-2.8.7-4 1.6z",slitlamp:"M2.5 14.5c2.2-3.5 5.6-5.3 9.5-5.3s7.3 1.8 9.5 5.3c-2.2 3.5-5.6 5.3-9.5 5.3s-7.3-1.8-9.5-5.3zM14.6 14.5a2.6 2.6 0 1 1-5.2 0 2.6 2.6 0 0 1 5.2 0zM13.7 9.3L18.6 3.4M17.2 2.6l2.8 2.3",microscope:"M9.2 2.8l3.2 1.2-3 8-3.2-1.2zM7.8 12.3l-.9 2.3M5.5 16.6h6.5M5 20.5h14M12.4 7.4c3.3.6 5.6 3.4 5.6 6.8 0 2.6-1.3 4.9-3.4 6.3",centrifuge:"M20.5 12a8.5 8.5 0 1 1-17 0 8.5 8.5 0 0 1 17 0zM13.6 7.4a1.6 1.6 0 1 1-3.2 0 1.6 1.6 0 0 1 3.2 0zM9.6 14.3a1.6 1.6 0 1 1-3.2 0 1.6 1.6 0 0 1 3.2 0zM17.6 14.3a1.6 1.6 0 1 1-3.2 0 1.6 1.6 0 0 1 3.2 0zM12 12h.01",autoclave:"M5 9h14a1.5 1.5 0 0 1 1.5 1.5v8.5a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5v-8.5A1.5 1.5 0 0 1 5 9zM15.6 14.8a3.6 3.6 0 1 1-7.2 0 3.6 3.6 0 0 1 7.2 0zM10.4 14.8h3.2M9.5 2.6c-.8.8-.8 1.6 0 2.4s.8 1.6 0 2.4M14.5 2.6c-.8.8-.8 1.6 0 2.4s.8 1.6 0 2.4"},Ts=n=>({...n,glyph:Ed[n.id],glyphSvg:U2(Ed[n.id])}),Ii={k:"Invoice",v:"GST tax invoice on every repair"},ir={k:"Payment",v:"Escrow; released when you confirm, or 48 h after completion"},nh=["Preventive visits weekly, every 2 weeks, monthly or quarterly","A primary engineer, plus fallbacks if they are unavailable","Response-time targets; a missed target triggers a goodwill credit","A countersigned report per visit with IEC 62353 safety and calibration results, filed by serial number","Spare parts: agree in the contract what is included; AMC brings parts discounts"],As=n=>[nh[0],`Checks you can add to the scope: ${n}`,...nh.slice(1)],Td=["Patient monitoring: basic vitals monitors","Dental: chairs, autoclaves, compressors and suction","Eye diagnostics: slit lamps, fundus cameras, OCT and perimeters","Laboratory: centrifuges, microscopes, water baths and incubators","Sterilisation: autoclaves and ultrasonic cleaners"],Ad="Life support, imaging and radiology, surgical, dialysis, IVD analysers and other Class C or D equipment. The app only offers equipment types we can service.",ih={brand:{name:"EquipSeva",tagline:"Verified biomedical engineers for the machines that keep India’s hospitals and clinics running.",lockup:["EQUIP","SEVA"]},loader:{line1:"INITIALISING SEVA NETWORK",line2:"LOADING, PLEASE WAIT"},intro:{wordmark:"EQUIPSEVA",cta:"CLICK TO ENTER",caption:"Hospitals never sleep. Neither can their machines.",descriptor:"Verified biomedical engineers for hospital and clinic equipment in India"},steps:[Ts({id:"monitor",name:"Vitals monitor",title:"EVERY BEAT",department:"Wards",time:"05:40",shift:"Dawn",story:"Before the dawn handover, a ward vitals monitor keeps losing its SpO2 reading. The biomedical lead posts the fault with photos; KYC-checked engineers nearby bid with a price and an ETA."}),Ts({id:"dental",name:"Dental chair",title:"OPEN WIDE",department:"Dental clinic",time:"09:00",shift:"Morning",story:"The first patient is due at nine and the chair won’t recline. The dentist picks a KYC-checked engineer by rating and brands serviced, then follows the job status until they check in."}),Ts({id:"slitlamp",name:"Slit lamp",title:"CLEAR SIGHT",department:"Eye OPD",time:"13:00",shift:"Noon",story:"By noon the eye OPD queue fills the corridor and the slit lamp’s beam starts to flicker. The engineer checks in with before-photos, fixes it and files a report the hospital countersigns."}),Ts({id:"microscope",name:"Lab microscope",title:"FINE FOCUS",department:"Pathology lab",time:"17:30",shift:"Dusk",story:"At dusk the pathology lab still has slides to read. A microscope that drifts out of focus slows every report, so the lab keeps it on an AMC with scheduled preventive visits."}),Ts({id:"centrifuge",name:"Lab centrifuge",title:"ROUND THE CLOCK",department:"24-hour lab",time:"21:00",shift:"Night",story:"Emergency samples arrive all night, and the 24-hour lab’s centrifuge starts to shake. Payment waits in escrow until the lab confirms the repair or, with no dispute, 48 hours after completion."}),Ts({id:"autoclave",name:"Autoclave",title:"NIGHT CYCLE",department:"CSSD",time:"02:00",shift:"Deep night",story:"At 2 a.m. the CSSD is sterilising trays for the first OT list. Whoever services its autoclave has had their Aadhaar, PAN and qualification certificate checked, and renews KYC every year."})],timeline:[{time:"05:40",label:"Dawn · Vitals monitor"},{time:"09:00",label:"Morning · Dental chair"},{time:"13:00",label:"Noon · Slit lamp"},{time:"17:30",label:"Dusk · Lab microscope"},{time:"21:00",label:"Night · Lab centrifuge"},{time:"02:00",label:"Deep night · Autoclave"}],explore:[{id:"monitor",headline:"Vitals monitors that read true",lead:"Post a monitor fault with photos, the brand and the model. KYC-checked engineers nearby bid with a price and an ETA, and you see the quote before you accept. Every repair closes with photos, a countersigned service report and a GST tax invoice.",fixes:["SpO2 probes and extension cables that drop the reading","NIBP cuff and hose leaks, and pump or valve errors","ECG lead-wire and temperature-probe faults","Display, keypad and backlight failures","Batteries that no longer hold charge, and power faults"],amc:As("SpO2, NIBP and temperature readings, alarms, cables and battery health"),engineer:"A biomedical engineer whose Aadhaar, PAN and qualification certificate our team checked before they could bid, and who renews KYC every year. Their profile shows the monitor brands they service, past jobs and ratings from other hospitals.",specs:[{k:"Bids",v:"Price and ETA, from KYC-checked engineers"},{k:"Proof",v:"Before/after photos, countersigned report"},Ii,ir],ctas:To("Vitals monitor")},{id:"dental",headline:"Dental chairs that rise, recline and rinse",lead:"Compare engineers by rating, brands serviced and past work, then follow the job status from en route to on site. Chat stays in the app, tied to the job, and you pay through Razorpay into EquipSeva escrow.",fixes:["Chairs that won’t rise, recline or hold position","Foot control and control-panel faults","Handpiece air and water lines: low pressure, leaks, no spray","Weak suction and spittoon water-flow problems","Operating light, solenoid valve and air-supply faults"],amc:As("chair movement, handpiece air and water lines, suction, spittoon and light"),engineer:"An independent engineer with dental equipment among their specialisations and a KYC-checked profile: Aadhaar, PAN and qualification certificate, renewed every year. You see their rating, brands serviced and past work before you accept.",specs:[{k:"Tracking",v:"Live job status, on-site check-in with photos"},{k:"Chat",v:"In the app, tied to the job"},Ii,ir],ctas:To("Dental chair")},{id:"slitlamp",headline:"Slit lamps with a steady beam",lead:"The engineer checks in on site with before-photos, closes the job with after-photos and files a digital service report your team countersigns. A GST tax invoice comes with every repair, for your records and input-tax credit.",fixes:["Flickering or dim illumination: bulb, LED, holder or transformer","Slit width, beam height and filter controls that stick","Joystick and base movement that drags or drifts","Eyepiece, prism and magnification-changer misalignment","Chin rest, table lift and power-supply faults"],amc:As("illumination, slit and filter controls, optics cleaning and alignment, joystick and table"),engineer:"An engineer with diagnostic eye equipment on their KYC-checked profile (Aadhaar, PAN and qualification certificate, renewed every year). Their profile lists the brands they service and ratings from other hospitals and clinics.",specs:[{k:"Check-in",v:"On site, with before-photos"},{k:"Scope",v:"Diagnostic eye equipment, not surgical"},Ii,ir],ctas:To("Slit lamp")},{id:"microscope",headline:"Microscopes that hold their focus",lead:"An AMC runs on a monthly fee: you pre-pay 1 to 12 months into its maintenance pool, and each completed visit deducts its share. You choose the cadence and write what each visit checks.",fixes:["Focus that drifts or won’t hold","Lamp, dimmer and power-supply faults","Fungus, haze or dirt on objectives and eyepieces","Stage drives and slide holders that stick or slip","Condenser, nosepiece and illumination alignment"],amc:As("optics cleaning and fungus checks, focus mechanism, stage and illumination alignment"),engineer:"Your contract names a primary engineer and fallbacks; if the primary is unavailable, the next one takes the visit. Each has passed KYC (Aadhaar, PAN and qualification certificate) and renews it every year.",specs:[{k:"Cadence",v:"Weekly, every 2 weeks, monthly or quarterly"},{k:"Cover",v:"Primary engineer plus fallbacks"},Ii,{k:"Payment",v:"Pre-paid pool, deducted per visit"}],ctas:[{label:"Ask about an AMC",href:Wh("Lab microscope")},Bs]},{id:"centrifuge",headline:"Centrifuges that spin true",lead:"You pay through Razorpay (UPI, card or net banking) into EquipSeva escrow. The engineer is paid when you confirm the job, or automatically 48 hours after completion unless you raise a dispute; then our team reviews both sides and decides on release or refund.",fixes:["Vibration, noise and imbalance cut-outs mid-run","Lid lock and lid switch faults that stop a run","Speed or timer errors, and worn motor brushes","Worn or damaged rotors, buckets and adaptors","Control-board and display faults; cooling faults on refrigerated models"],amc:As("speed and timer checks, lid lock, rotor and bucket inspection, imbalance cut-out"),engineer:"A biomedical engineer with lab equipment among their specialisations, KYC-checked before they could bid. Once the job is confirmed, their share goes to their UPI or bank account, with EquipSeva’s fee deducted automatically.",specs:[{k:"Methods",v:"UPI, card or net banking via Razorpay"},{k:"Disputes",v:"Our team reviews both sides"},Ii,ir],ctas:To("Lab centrifuge")},{id:"autoclave",headline:"Autoclaves ready for the morning list",lead:"Every engineer who can bid has cleared KYC: Aadhaar, PAN and a qualification certificate, checked by our team and renewed every year. Each job ends in a countersigned report, filed under the autoclave’s serial number for your audit trail.",fixes:["Door gasket leaks and door-lock faults","Failed Bowie-Dick (air-removal) tests and vacuum-pump faults","Heater, steam-generator and water-level faults","Chamber temperature or pressure out of OEM tolerance","Controller, printer and cycle-record errors"],amc:As("door gasket and lock, vacuum leak test, temperature and pressure readings, cycle records"),engineer:"An engineer with sterilisation equipment among their specialisations. Their profile shows the brands they service, past jobs and ratings from other hospitals, and you see their quote before you accept.",specs:[{k:"KYC",v:"Aadhaar, PAN, certificate checked; renewed yearly"},{k:"Proof",v:"Countersigned report, filed by serial number"},Ii,ir],ctas:To("Autoclave")}],pages:{hospitals:{id:"hospitals",label:"Hospitals",kicker:"For hospitals and clinics",headline:"Book a verified engineer for your equipment",lead:"Post a repair or set up an AMC in the EquipSeva app. KYC-checked biomedical engineers nearby bid with a price and an ETA, you see the quote before you accept, and your payment waits in escrow until the job is done.",sections:[{title:"Equipment we service today",items:Td},{title:"Not yet",text:Ad}],specs:[{k:"Methods",v:"UPI, card or net banking via Razorpay"},{k:"Proof",v:"Before/after photos, countersigned report"},Ii,ir],ctas:[{label:"Request service",href:fl()},qa]},engineers:{id:"engineers",label:"Engineers",kicker:"For biomedical engineers",headline:"Bid on equipment jobs near you",lead:"Complete KYC once (Aadhaar, PAN and qualification certificate, usually reviewed within a day and renewed every year), set the area you cover, and bid with your price and ETA. When the hospital confirms the job, your share goes to your UPI or bank account; EquipSeva’s commission is deducted automatically.",sections:[{title:"How it works for engineers",items:["Clear KYC once: Aadhaar, PAN and a qualification certificate","Set the area you cover and the brands you service","Bid on nearby jobs with your price and ETA","Check in on site with before-photos; close with after-photos and a service report","Get paid to UPI or bank once the job is confirmed, or 48 hours after completion if there is no dispute"]}],specs:[{k:"KYC",v:"Aadhaar, PAN, certificate; renewed yearly"},{k:"Review",v:"Usually within a day"},{k:"Payout",v:"UPI or bank account"},{k:"Fee",v:"Platform commission, deducted automatically"}],ctas:[Bs,qa]},amc:{id:"amc",label:"AMC contracts",kicker:"Annual maintenance contracts",headline:"Scheduled visits, paid from a pre-paid pool",lead:"The contract runs on a monthly fee: you pre-pay 1 to 12 months into its maintenance pool, and each completed visit deducts its share. You choose the cadence and write what each visit checks.",sections:[{title:"What an AMC gives you",items:nh}],specs:[{k:"Cadence",v:"Weekly, every 2 weeks, monthly or quarterly"},{k:"Cover",v:"Primary engineer plus fallbacks"},{k:"Payment",v:"Pre-paid pool, deducted per visit"},{k:"Parts",v:"Discounts; inclusions as your contract says"}],ctas:[{label:"Ask about an AMC",href:I2},qa]},how:{id:"how",label:"How it works",kicker:"How it works",headline:"From fault to fixed, with proof",lead:"Four steps in the EquipSeva app, from the first photo to the countersigned report.",sections:[{title:"Four steps",items:["Post the job: equipment, brand, model, fault, photos and your site address.","Compare bids: KYC-checked engineers nearby quote a price and ETA; you see ratings, brands serviced and past work.","Pay into escrow through Razorpay (UPI, card or net banking) and follow the status: en route, on site, in progress.","Close with proof: before and after photos, a digital service report you countersign, and a GST tax invoice. The engineer is paid when you confirm, or 48 hours after completion unless you raise a dispute; our team reviews both sides."]}],specs:[{k:"Quote",v:"You see the engineer’s quote before you accept"},{k:"Status",v:"Assigned, en route, in progress, completed"},Ii,ir],ctas:[{label:"Request service",href:fl()},Bs]},about:{id:"about",label:"About",kicker:"About EquipSeva",headline:"Why EquipSeva exists",lead:"Hospitals and clinics depend on equipment that needs timely, documented service. EquipSeva is a marketplace that connects them with independent, KYC-checked biomedical engineers, holds the payment in escrow until the job is done, and keeps the proof on record.",sections:[{title:"Equipment we service today",items:Td},{title:"Not yet",text:Ad}],specs:[{k:"Engineers",v:"Independent, KYC-checked"},{k:"Records",v:"Photos, countersigned reports, GST invoices"},{k:"Payments",v:"Razorpay into EquipSeva escrow"},{k:"Contact",v:Xo}],ctas:[qa,{label:"Privacy policy",href:wd[0].href}]}},menu:[{label:"Hospitals",page:"hospitals",href:"#hospitals",desc:"Post a repair, compare bids, pay through escrow"},{label:"Engineers",page:"engineers",href:"#engineers",desc:"Clear KYC once, then bid on jobs near you"},{label:"AMC contracts",page:"amc",href:"#amc",desc:"Scheduled visits paid from a pre-paid pool"},{label:"How it works",page:"how",href:"#how",desc:"Post, compare bids, follow the job, close with proof"},{label:"About",page:"about",href:"#about",desc:"What we service today, and what we don’t yet"},{label:"Contact",href:fp,desc:Xo}],ctas:{primary:{label:"Request service",href:fl()},secondary:Bs},legal:wd,captionLines:["VERIFIED ENGINEERS FOR","THE MACHINES THAT","KEEP CARE MOVING"],labels:{menu:"Menu",close:"Close",explore:"Explore",prev:"Prev",next:"Next",drag:"Drag through the day",story:"Story",timeline:"Timeline",sound:"Sound",on:"On",off:"Off",fixesTitle:"Common faults engineers fix",amcTitle:"What an AMC gives you",engineerTitle:"Your engineer",escHint:"to close"},menuFoot:"Made in India for India’s hospitals and clinics.",contact:{email:Xo,location:"Hyderabad, Telangana",phone:"",whatsapp:""}},Xh="monitor",Cd={dental:{title:"ON THE WAY",story:"By nine the ward lead has compared the bids. She picks an engineer by rating and the monitor brands they service, then follows the job status until they check in.",headline:"Pick an engineer, then follow the job"},slitlamp:{title:"PROOF ON SITE",story:"At noon the engineer checks in with before-photos, replaces the worn SpO2 cable and tests every reading. The job closes with after-photos and a report the ward countersigns.",headline:"Proof on every job",specs:[{k:"Check-in",v:"On site, with before-photos"},{k:"Proof",v:"Before/after photos, countersigned report"},Ii,ir]},microscope:{title:"ON SCHEDULE",story:"By dusk the ward has put its monitors on an AMC: preventive visits on a cadence it chooses, a primary engineer with fallbacks and a countersigned report for every visit.",headline:"Monitors on a maintenance contract",ctas:[{label:"Ask about an AMC",href:Wh("Vitals monitor")},Bs]},centrifuge:{title:"HELD IN ESCROW",story:"At night the payment still sits in EquipSeva escrow. It goes to the engineer when the ward confirms the repair or, with no dispute, 48 hours after completion.",headline:"Paid through escrow"},autoclave:{title:"KNOWN BY NAME",story:"At two in the morning the ward’s monitors read true. The engineer who fixed the faulty one had cleared KYC first: Aadhaar, PAN and qualification certificate, renewed every year.",headline:"Engineers checked before they bid",lead:"Every engineer who can bid has cleared KYC: Aadhaar, PAN and a qualification certificate, checked by our team and renewed every year. Each job ends in a countersigned report, filed under the monitor’s serial number for your audit trail."}};function N2(n,e=[]){const t=new Set(e),i=n.steps.findIndex(a=>a.id===Xh);if(i<0||!n.steps.some(a=>t.has(a.id)&&Cd[a.id]))return n;const r=n.steps[i],s=n.explore[i],o=a=>t.has(n.steps[a].id)&&Cd[n.steps[a].id];return{...n,steps:n.steps.map((a,l)=>{const c=o(l);return c?{...a,name:r.name,department:r.department,glyph:r.glyph,glyphSvg:r.glyphSvg,title:c.title,story:c.story,interim:!0}:a}),timeline:n.timeline.map((a,l)=>o(l)?{...a,label:`${n.steps[l].shift} · ${r.name}`}:a),explore:n.explore.map((a,l)=>{const c=o(l);return c?{...s,id:a.id,headline:c.headline,lead:c.lead||a.lead,specs:c.specs||a.specs,ctas:c.ctas||s.ctas,interim:!0}:a})}}function Ui(n){if(n===void 0)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return n}function dp(n,e){n.prototype=Object.create(e.prototype),n.prototype.constructor=n,n.__proto__=e}/*!
 * GSAP 3.12.5
 * https://gsap.com
 *
 * @license Copyright 2008-2024, GreenSock. All rights reserved.
 * Subject to the terms at https://gsap.com/standard-license or for
 * Club GSAP members, the agreement issued with that membership.
 * @author: Jack Doyle, jack@greensock.com
*/var Vn={autoSleep:120,force3D:"auto",nullTargetWarn:1,units:{lineHeight:""}},io={duration:.5,overwrite:!1,delay:0},qh,pn,Dt,Jn=1e8,At=1/Jn,rh=Math.PI*2,F2=rh/4,O2=0,pp=Math.sqrt,k2=Math.cos,B2=Math.sin,rn=function(e){return typeof e=="string"},Bt=function(e){return typeof e=="function"},Gi=function(e){return typeof e=="number"},$h=function(e){return typeof e>"u"},bi=function(e){return typeof e=="object"},Cn=function(e){return e!==!1},Yh=function(){return typeof window<"u"},$a=function(e){return Bt(e)||rn(e)},mp=typeof ArrayBuffer=="function"&&ArrayBuffer.isView||function(){},mn=Array.isArray,sh=/(?:-?\.?\d|\.)+/gi,gp=/[-+=.]*\d+[.e\-+]*\d*[e\-+]*\d*/g,zs=/[-+=.]*\d+[.e-]*\d*[a-z%]*/g,Oc=/[-+=.]*\d+\.?\d*(?:e-|e\+)?\d*/gi,vp=/[+-]=-?[.\d]+/,_p=/[^,'"\[\]\s]+/gi,z2=/^[+\-=e\s\d]*\d+[.\d]*([a-z]*|%)\s*$/i,Nt,mi,oh,Kh,Wn={},Tl={},xp,yp=function(e){return(Tl=ts(e,Wn))&&Ht},jh=function(e,t){return console.warn("Invalid property",e,"set to",t,"Missing plugin? gsap.registerPlugin()")},ta=function(e,t){return!t&&console.warn(e)},Sp=function(e,t){return e&&(Wn[e]=t)&&Tl&&(Tl[e]=t)||Wn},na=function(){return 0},H2={suppressEvents:!0,isStart:!0,kill:!1},dl={suppressEvents:!0,kill:!1},G2={suppressEvents:!0},Zh={},mr=[],ah={},Mp,On={},kc={},Rd=30,pl=[],Jh="",Qh=function(e){var t=e[0],i,r;if(bi(t)||Bt(t)||(e=[e]),!(i=(t._gsap||{}).harness)){for(r=pl.length;r--&&!pl[r].targetTest(t););i=pl[r]}for(r=e.length;r--;)e[r]&&(e[r]._gsap||(e[r]._gsap=new qp(e[r],i)))||e.splice(r,1);return e},qr=function(e){return e._gsap||Qh(Qn(e))[0]._gsap},bp=function(e,t,i){return(i=e[t])&&Bt(i)?e[t]():$h(i)&&e.getAttribute&&e.getAttribute(t)||i},Rn=function(e,t){return(e=e.split(",")).forEach(t)||e},zt=function(e){return Math.round(e*1e5)/1e5||0},nn=function(e){return Math.round(e*1e7)/1e7||0},Ys=function(e,t){var i=t.charAt(0),r=parseFloat(t.substr(2));return e=parseFloat(e),i==="+"?e+r:i==="-"?e-r:i==="*"?e*r:e/r},V2=function(e,t){for(var i=t.length,r=0;e.indexOf(t[r])<0&&++r<i;);return r<i},Al=function(){var e=mr.length,t=mr.slice(0),i,r;for(ah={},mr.length=0,i=0;i<e;i++)r=t[i],r&&r._lazy&&(r.render(r._lazy[0],r._lazy[1],!0)._lazy=0)},wp=function(e,t,i,r){mr.length&&!pn&&Al(),e.render(t,i,pn&&t<0&&(e._initted||e._startAt)),mr.length&&!pn&&Al()},Ep=function(e){var t=parseFloat(e);return(t||t===0)&&(e+"").match(_p).length<2?t:rn(e)?e.trim():e},Tp=function(e){return e},ei=function(e,t){for(var i in t)i in e||(e[i]=t[i]);return e},W2=function(e){return function(t,i){for(var r in i)r in t||r==="duration"&&e||r==="ease"||(t[r]=i[r])}},ts=function(e,t){for(var i in t)e[i]=t[i];return e},Pd=function n(e,t){for(var i in t)i!=="__proto__"&&i!=="constructor"&&i!=="prototype"&&(e[i]=bi(t[i])?n(e[i]||(e[i]={}),t[i]):t[i]);return e},Cl=function(e,t){var i={},r;for(r in e)r in t||(i[r]=e[r]);return i},qo=function(e){var t=e.parent||Nt,i=e.keyframes?W2(mn(e.keyframes)):ei;if(Cn(e.inherit))for(;t;)i(e,t.vars.defaults),t=t.parent||t._dp;return e},X2=function(e,t){for(var i=e.length,r=i===t.length;r&&i--&&e[i]===t[i];);return i<0},Ap=function(e,t,i,r,s){var o=e[r],a;if(s)for(a=t[s];o&&o[s]>a;)o=o._prev;return o?(t._next=o._next,o._next=t):(t._next=e[i],e[i]=t),t._next?t._next._prev=t:e[r]=t,t._prev=o,t.parent=t._dp=e,t},Zl=function(e,t,i,r){i===void 0&&(i="_first"),r===void 0&&(r="_last");var s=t._prev,o=t._next;s?s._next=o:e[i]===t&&(e[i]=o),o?o._prev=s:e[r]===t&&(e[r]=s),t._next=t._prev=t.parent=null},yr=function(e,t){e.parent&&(!t||e.parent.autoRemoveChildren)&&e.parent.remove&&e.parent.remove(e),e._act=0},$r=function(e,t){if(e&&(!t||t._end>e._dur||t._start<0))for(var i=e;i;)i._dirty=1,i=i.parent;return e},q2=function(e){for(var t=e.parent;t&&t.parent;)t._dirty=1,t.totalDuration(),t=t.parent;return e},lh=function(e,t,i,r){return e._startAt&&(pn?e._startAt.revert(dl):e.vars.immediateRender&&!e.vars.autoRevert||e._startAt.render(t,!0,r))},$2=function n(e){return!e||e._ts&&n(e.parent)},Ld=function(e){return e._repeat?ro(e._tTime,e=e.duration()+e._rDelay)*e:0},ro=function(e,t){var i=Math.floor(e/=t);return e&&i===e?i-1:i},Rl=function(e,t){return(e-t._start)*t._ts+(t._ts>=0?0:t._dirty?t.totalDuration():t._tDur)},Jl=function(e){return e._end=nn(e._start+(e._tDur/Math.abs(e._ts||e._rts||At)||0))},Ql=function(e,t){var i=e._dp;return i&&i.smoothChildTiming&&e._ts&&(e._start=nn(i._time-(e._ts>0?t/e._ts:((e._dirty?e.totalDuration():e._tDur)-t)/-e._ts)),Jl(e),i._dirty||$r(i,e)),e},Cp=function(e,t){var i;if((t._time||!t._dur&&t._initted||t._start<e._time&&(t._dur||!t.add))&&(i=Rl(e.rawTime(),t),(!t._dur||pa(0,t.totalDuration(),i)-t._tTime>At)&&t.render(i,!0)),$r(e,t)._dp&&e._initted&&e._time>=e._dur&&e._ts){if(e._dur<e.duration())for(i=e;i._dp;)i.rawTime()>=0&&i.totalTime(i._tTime),i=i._dp;e._zTime=-At}},vi=function(e,t,i,r){return t.parent&&yr(t),t._start=nn((Gi(i)?i:i||e!==Nt?Kn(e,i,t):e._time)+t._delay),t._end=nn(t._start+(t.totalDuration()/Math.abs(t.timeScale())||0)),Ap(e,t,"_first","_last",e._sort?"_start":0),ch(t)||(e._recent=t),r||Cp(e,t),e._ts<0&&Ql(e,e._tTime),e},Rp=function(e,t){return(Wn.ScrollTrigger||jh("scrollTrigger",t))&&Wn.ScrollTrigger.create(t,e)},Pp=function(e,t,i,r,s){if(tf(e,t,s),!e._initted)return 1;if(!i&&e._pt&&!pn&&(e._dur&&e.vars.lazy!==!1||!e._dur&&e.vars.lazy)&&Mp!==zn.frame)return mr.push(e),e._lazy=[s,r],1},Y2=function n(e){var t=e.parent;return t&&t._ts&&t._initted&&!t._lock&&(t.rawTime()<0||n(t))},ch=function(e){var t=e.data;return t==="isFromStart"||t==="isStart"},K2=function(e,t,i,r){var s=e.ratio,o=t<0||!t&&(!e._start&&Y2(e)&&!(!e._initted&&ch(e))||(e._ts<0||e._dp._ts<0)&&!ch(e))?0:1,a=e._rDelay,l=0,c,u,h;if(a&&e._repeat&&(l=pa(0,e._tDur,t),u=ro(l,a),e._yoyo&&u&1&&(o=1-o),u!==ro(e._tTime,a)&&(s=1-o,e.vars.repeatRefresh&&e._initted&&e.invalidate())),o!==s||pn||r||e._zTime===At||!t&&e._zTime){if(!e._initted&&Pp(e,t,r,i,l))return;for(h=e._zTime,e._zTime=t||(i?At:0),i||(i=t&&!h),e.ratio=o,e._from&&(o=1-o),e._time=0,e._tTime=l,c=e._pt;c;)c.r(o,c.d),c=c._next;t<0&&lh(e,t,i,!0),e._onUpdate&&!i&&Gn(e,"onUpdate"),l&&e._repeat&&!i&&e.parent&&Gn(e,"onRepeat"),(t>=e._tDur||t<0)&&e.ratio===o&&(o&&yr(e,1),!i&&!pn&&(Gn(e,o?"onComplete":"onReverseComplete",!0),e._prom&&e._prom()))}else e._zTime||(e._zTime=t)},j2=function(e,t,i){var r;if(i>t)for(r=e._first;r&&r._start<=i;){if(r.data==="isPause"&&r._start>t)return r;r=r._next}else for(r=e._last;r&&r._start>=i;){if(r.data==="isPause"&&r._start<t)return r;r=r._prev}},so=function(e,t,i,r){var s=e._repeat,o=nn(t)||0,a=e._tTime/e._tDur;return a&&!r&&(e._time*=o/e._dur),e._dur=o,e._tDur=s?s<0?1e10:nn(o*(s+1)+e._rDelay*s):o,a>0&&!r&&Ql(e,e._tTime=e._tDur*a),e.parent&&Jl(e),i||$r(e.parent,e),e},Dd=function(e){return e instanceof xn?$r(e):so(e,e._dur)},Z2={_start:0,endTime:na,totalDuration:na},Kn=function n(e,t,i){var r=e.labels,s=e._recent||Z2,o=e.duration()>=Jn?s.endTime(!1):e._dur,a,l,c;return rn(t)&&(isNaN(t)||t in r)?(l=t.charAt(0),c=t.substr(-1)==="%",a=t.indexOf("="),l==="<"||l===">"?(a>=0&&(t=t.replace(/=/,"")),(l==="<"?s._start:s.endTime(s._repeat>=0))+(parseFloat(t.substr(1))||0)*(c?(a<0?s:i).totalDuration()/100:1)):a<0?(t in r||(r[t]=o),r[t]):(l=parseFloat(t.charAt(a-1)+t.substr(a+1)),c&&i&&(l=l/100*(mn(i)?i[0]:i).totalDuration()),a>1?n(e,t.substr(0,a-1),i)+l:o+l)):t==null?o:+t},$o=function(e,t,i){var r=Gi(t[1]),s=(r?2:1)+(e<2?0:1),o=t[s],a,l;if(r&&(o.duration=t[1]),o.parent=i,e){for(a=o,l=i;l&&!("immediateRender"in a);)a=l.vars.defaults||{},l=Cn(l.vars.inherit)&&l.parent;o.immediateRender=Cn(a.immediateRender),e<2?o.runBackwards=1:o.startAt=t[s-1]}return new qt(t[0],o,t[s+1])},wr=function(e,t){return e||e===0?t(e):t},pa=function(e,t,i){return i<e?e:i>t?t:i},fn=function(e,t){return!rn(e)||!(t=z2.exec(e))?"":t[1]},J2=function(e,t,i){return wr(i,function(r){return pa(e,t,r)})},uh=[].slice,Lp=function(e,t){return e&&bi(e)&&"length"in e&&(!t&&!e.length||e.length-1 in e&&bi(e[0]))&&!e.nodeType&&e!==mi},Q2=function(e,t,i){return i===void 0&&(i=[]),e.forEach(function(r){var s;return rn(r)&&!t||Lp(r,1)?(s=i).push.apply(s,Qn(r)):i.push(r)})||i},Qn=function(e,t,i){return Dt&&!t&&Dt.selector?Dt.selector(e):rn(e)&&!i&&(oh||!oo())?uh.call((t||Kh).querySelectorAll(e),0):mn(e)?Q2(e,i):Lp(e)?uh.call(e,0):e?[e]:[]},hh=function(e){return e=Qn(e)[0]||ta("Invalid scope")||{},function(t){var i=e.current||e.nativeElement||e;return Qn(t,i.querySelectorAll?i:i===e?ta("Invalid scope")||Kh.createElement("div"):e)}},Dp=function(e){return e.sort(function(){return .5-Math.random()})},Ip=function(e){if(Bt(e))return e;var t=bi(e)?e:{each:e},i=Yr(t.ease),r=t.from||0,s=parseFloat(t.base)||0,o={},a=r>0&&r<1,l=isNaN(r)||a,c=t.axis,u=r,h=r;return rn(r)?u=h={center:.5,edges:.5,end:1}[r]||0:!a&&l&&(u=r[0],h=r[1]),function(f,d,v){var g=(v||t).length,p=o[g],m,x,_,y,C,M,w,P,I;if(!p){if(I=t.grid==="auto"?0:(t.grid||[1,Jn])[1],!I){for(w=-Jn;w<(w=v[I++].getBoundingClientRect().left)&&I<g;);I<g&&I--}for(p=o[g]=[],m=l?Math.min(I,g)*u-.5:r%I,x=I===Jn?0:l?g*h/I-.5:r/I|0,w=0,P=Jn,M=0;M<g;M++)_=M%I-m,y=x-(M/I|0),p[M]=C=c?Math.abs(c==="y"?y:_):pp(_*_+y*y),C>w&&(w=C),C<P&&(P=C);r==="random"&&Dp(p),p.max=w-P,p.min=P,p.v=g=(parseFloat(t.amount)||parseFloat(t.each)*(I>g?g-1:c?c==="y"?g/I:I:Math.max(I,g/I))||0)*(r==="edges"?-1:1),p.b=g<0?s-g:s,p.u=fn(t.amount||t.each)||0,i=i&&g<0?Vp(i):i}return g=(p[f]-p.min)/p.max||0,nn(p.b+(i?i(g):g)*p.v)+p.u}},fh=function(e){var t=Math.pow(10,((e+"").split(".")[1]||"").length);return function(i){var r=nn(Math.round(parseFloat(i)/e)*e*t);return(r-r%1)/t+(Gi(i)?0:fn(i))}},Up=function(e,t){var i=mn(e),r,s;return!i&&bi(e)&&(r=i=e.radius||Jn,e.values?(e=Qn(e.values),(s=!Gi(e[0]))&&(r*=r)):e=fh(e.increment)),wr(t,i?Bt(e)?function(o){return s=e(o),Math.abs(s-o)<=r?s:o}:function(o){for(var a=parseFloat(s?o.x:o),l=parseFloat(s?o.y:0),c=Jn,u=0,h=e.length,f,d;h--;)s?(f=e[h].x-a,d=e[h].y-l,f=f*f+d*d):f=Math.abs(e[h]-a),f<c&&(c=f,u=h);return u=!r||c<=r?e[u]:o,s||u===o||Gi(o)?u:u+fn(o)}:fh(e))},Np=function(e,t,i,r){return wr(mn(e)?!t:i===!0?!!(i=0):!r,function(){return mn(e)?e[~~(Math.random()*e.length)]:(i=i||1e-5)&&(r=i<1?Math.pow(10,(i+"").length-2):1)&&Math.floor(Math.round((e-i/2+Math.random()*(t-e+i*.99))/i)*i*r)/r})},eS=function(){for(var e=arguments.length,t=new Array(e),i=0;i<e;i++)t[i]=arguments[i];return function(r){return t.reduce(function(s,o){return o(s)},r)}},tS=function(e,t){return function(i){return e(parseFloat(i))+(t||fn(i))}},nS=function(e,t,i){return Op(e,t,0,1,i)},Fp=function(e,t,i){return wr(i,function(r){return e[~~t(r)]})},iS=function n(e,t,i){var r=t-e;return mn(e)?Fp(e,n(0,e.length),t):wr(i,function(s){return(r+(s-e)%r)%r+e})},rS=function n(e,t,i){var r=t-e,s=r*2;return mn(e)?Fp(e,n(0,e.length-1),t):wr(i,function(o){return o=(s+(o-e)%s)%s||0,e+(o>r?s-o:o)})},ia=function(e){for(var t=0,i="",r,s,o,a;~(r=e.indexOf("random(",t));)o=e.indexOf(")",r),a=e.charAt(r+7)==="[",s=e.substr(r+7,o-r-7).match(a?_p:sh),i+=e.substr(t,r-t)+Np(a?s:+s[0],a?0:+s[1],+s[2]||1e-5),t=o+1;return i+e.substr(t,e.length-t)},Op=function(e,t,i,r,s){var o=t-e,a=r-i;return wr(s,function(l){return i+((l-e)/o*a||0)})},sS=function n(e,t,i,r){var s=isNaN(e+t)?0:function(d){return(1-d)*e+d*t};if(!s){var o=rn(e),a={},l,c,u,h,f;if(i===!0&&(r=1)&&(i=null),o)e={p:e},t={p:t};else if(mn(e)&&!mn(t)){for(u=[],h=e.length,f=h-2,c=1;c<h;c++)u.push(n(e[c-1],e[c]));h--,s=function(v){v*=h;var g=Math.min(f,~~v);return u[g](v-g)},i=t}else r||(e=ts(mn(e)?[]:{},e));if(!u){for(l in t)ef.call(a,e,l,"get",t[l]);s=function(v){return sf(v,a)||(o?e.p:e)}}}return wr(i,s)},Id=function(e,t,i){var r=e.labels,s=Jn,o,a,l;for(o in r)a=r[o]-t,a<0==!!i&&a&&s>(a=Math.abs(a))&&(l=o,s=a);return l},Gn=function(e,t,i){var r=e.vars,s=r[t],o=Dt,a=e._ctx,l,c,u;if(s)return l=r[t+"Params"],c=r.callbackScope||e,i&&mr.length&&Al(),a&&(Dt=a),u=l?s.apply(c,l):s.call(c),Dt=o,u},Fo=function(e){return yr(e),e.scrollTrigger&&e.scrollTrigger.kill(!!pn),e.progress()<1&&Gn(e,"onInterrupt"),e},Hs,kp=[],Bp=function(e){if(e)if(e=!e.name&&e.default||e,Yh()||e.headless){var t=e.name,i=Bt(e),r=t&&!i&&e.init?function(){this._props=[]}:e,s={init:na,render:sf,add:ef,kill:SS,modifier:yS,rawVars:0},o={targetTest:0,get:0,getSetter:rf,aliases:{},register:0};if(oo(),e!==r){if(On[t])return;ei(r,ei(Cl(e,s),o)),ts(r.prototype,ts(s,Cl(e,o))),On[r.prop=t]=r,e.targetTest&&(pl.push(r),Zh[t]=1),t=(t==="css"?"CSS":t.charAt(0).toUpperCase()+t.substr(1))+"Plugin"}Sp(t,r),e.register&&e.register(Ht,r,Pn)}else kp.push(e)},bt=255,Oo={aqua:[0,bt,bt],lime:[0,bt,0],silver:[192,192,192],black:[0,0,0],maroon:[128,0,0],teal:[0,128,128],blue:[0,0,bt],navy:[0,0,128],white:[bt,bt,bt],olive:[128,128,0],yellow:[bt,bt,0],orange:[bt,165,0],gray:[128,128,128],purple:[128,0,128],green:[0,128,0],red:[bt,0,0],pink:[bt,192,203],cyan:[0,bt,bt],transparent:[bt,bt,bt,0]},Bc=function(e,t,i){return e+=e<0?1:e>1?-1:0,(e*6<1?t+(i-t)*e*6:e<.5?i:e*3<2?t+(i-t)*(2/3-e)*6:t)*bt+.5|0},zp=function(e,t,i){var r=e?Gi(e)?[e>>16,e>>8&bt,e&bt]:0:Oo.black,s,o,a,l,c,u,h,f,d,v;if(!r){if(e.substr(-1)===","&&(e=e.substr(0,e.length-1)),Oo[e])r=Oo[e];else if(e.charAt(0)==="#"){if(e.length<6&&(s=e.charAt(1),o=e.charAt(2),a=e.charAt(3),e="#"+s+s+o+o+a+a+(e.length===5?e.charAt(4)+e.charAt(4):"")),e.length===9)return r=parseInt(e.substr(1,6),16),[r>>16,r>>8&bt,r&bt,parseInt(e.substr(7),16)/255];e=parseInt(e.substr(1),16),r=[e>>16,e>>8&bt,e&bt]}else if(e.substr(0,3)==="hsl"){if(r=v=e.match(sh),!t)l=+r[0]%360/360,c=+r[1]/100,u=+r[2]/100,o=u<=.5?u*(c+1):u+c-u*c,s=u*2-o,r.length>3&&(r[3]*=1),r[0]=Bc(l+1/3,s,o),r[1]=Bc(l,s,o),r[2]=Bc(l-1/3,s,o);else if(~e.indexOf("="))return r=e.match(gp),i&&r.length<4&&(r[3]=1),r}else r=e.match(sh)||Oo.transparent;r=r.map(Number)}return t&&!v&&(s=r[0]/bt,o=r[1]/bt,a=r[2]/bt,h=Math.max(s,o,a),f=Math.min(s,o,a),u=(h+f)/2,h===f?l=c=0:(d=h-f,c=u>.5?d/(2-h-f):d/(h+f),l=h===s?(o-a)/d+(o<a?6:0):h===o?(a-s)/d+2:(s-o)/d+4,l*=60),r[0]=~~(l+.5),r[1]=~~(c*100+.5),r[2]=~~(u*100+.5)),i&&r.length<4&&(r[3]=1),r},Hp=function(e){var t=[],i=[],r=-1;return e.split(gr).forEach(function(s){var o=s.match(zs)||[];t.push.apply(t,o),i.push(r+=o.length+1)}),t.c=i,t},Ud=function(e,t,i){var r="",s=(e+r).match(gr),o=t?"hsla(":"rgba(",a=0,l,c,u,h;if(!s)return e;if(s=s.map(function(f){return(f=zp(f,t,1))&&o+(t?f[0]+","+f[1]+"%,"+f[2]+"%,"+f[3]:f.join(","))+")"}),i&&(u=Hp(e),l=i.c,l.join(r)!==u.c.join(r)))for(c=e.replace(gr,"1").split(zs),h=c.length-1;a<h;a++)r+=c[a]+(~l.indexOf(a)?s.shift()||o+"0,0,0,0)":(u.length?u:s.length?s:i).shift());if(!c)for(c=e.split(gr),h=c.length-1;a<h;a++)r+=c[a]+s[a];return r+c[h]},gr=function(){var n="(?:\\b(?:(?:rgb|rgba|hsl|hsla)\\(.+?\\))|\\B#(?:[0-9a-f]{3,4}){1,2}\\b",e;for(e in Oo)n+="|"+e+"\\b";return new RegExp(n+")","gi")}(),oS=/hsl[a]?\(/,Gp=function(e){var t=e.join(" "),i;if(gr.lastIndex=0,gr.test(t))return i=oS.test(t),e[1]=Ud(e[1],i),e[0]=Ud(e[0],i,Hp(e[1])),!0},ra,zn=function(){var n=Date.now,e=500,t=33,i=n(),r=i,s=1e3/240,o=s,a=[],l,c,u,h,f,d,v=function g(p){var m=n()-r,x=p===!0,_,y,C,M;if((m>e||m<0)&&(i+=m-t),r+=m,C=r-i,_=C-o,(_>0||x)&&(M=++h.frame,f=C-h.time*1e3,h.time=C=C/1e3,o+=_+(_>=s?4:s-_),y=1),x||(l=c(g)),y)for(d=0;d<a.length;d++)a[d](C,f,M,p)};return h={time:0,frame:0,tick:function(){v(!0)},deltaRatio:function(p){return f/(1e3/(p||60))},wake:function(){xp&&(!oh&&Yh()&&(mi=oh=window,Kh=mi.document||{},Wn.gsap=Ht,(mi.gsapVersions||(mi.gsapVersions=[])).push(Ht.version),yp(Tl||mi.GreenSockGlobals||!mi.gsap&&mi||{}),kp.forEach(Bp)),u=typeof requestAnimationFrame<"u"&&requestAnimationFrame,l&&h.sleep(),c=u||function(p){return setTimeout(p,o-h.time*1e3+1|0)},ra=1,v(2))},sleep:function(){(u?cancelAnimationFrame:clearTimeout)(l),ra=0,c=na},lagSmoothing:function(p,m){e=p||1/0,t=Math.min(m||33,e)},fps:function(p){s=1e3/(p||240),o=h.time*1e3+s},add:function(p,m,x){var _=m?function(y,C,M,w){p(y,C,M,w),h.remove(_)}:p;return h.remove(p),a[x?"unshift":"push"](_),oo(),_},remove:function(p,m){~(m=a.indexOf(p))&&a.splice(m,1)&&d>=m&&d--},_listeners:a},h}(),oo=function(){return!ra&&zn.wake()},at={},aS=/^[\d.\-M][\d.\-,\s]/,lS=/["']/g,cS=function(e){for(var t={},i=e.substr(1,e.length-3).split(":"),r=i[0],s=1,o=i.length,a,l,c;s<o;s++)l=i[s],a=s!==o-1?l.lastIndexOf(","):l.length,c=l.substr(0,a),t[r]=isNaN(c)?c.replace(lS,"").trim():+c,r=l.substr(a+1).trim();return t},uS=function(e){var t=e.indexOf("(")+1,i=e.indexOf(")"),r=e.indexOf("(",t);return e.substring(t,~r&&r<i?e.indexOf(")",i+1):i)},hS=function(e){var t=(e+"").split("("),i=at[t[0]];return i&&t.length>1&&i.config?i.config.apply(null,~e.indexOf("{")?[cS(t[1])]:uS(e).split(",").map(Ep)):at._CE&&aS.test(e)?at._CE("",e):i},Vp=function(e){return function(t){return 1-e(1-t)}},Wp=function n(e,t){for(var i=e._first,r;i;)i instanceof xn?n(i,t):i.vars.yoyoEase&&(!i._yoyo||!i._repeat)&&i._yoyo!==t&&(i.timeline?n(i.timeline,t):(r=i._ease,i._ease=i._yEase,i._yEase=r,i._yoyo=t)),i=i._next},Yr=function(e,t){return e&&(Bt(e)?e:at[e]||hS(e))||t},ls=function(e,t,i,r){i===void 0&&(i=function(l){return 1-t(1-l)}),r===void 0&&(r=function(l){return l<.5?t(l*2)/2:1-t((1-l)*2)/2});var s={easeIn:t,easeOut:i,easeInOut:r},o;return Rn(e,function(a){at[a]=Wn[a]=s,at[o=a.toLowerCase()]=i;for(var l in s)at[o+(l==="easeIn"?".in":l==="easeOut"?".out":".inOut")]=at[a+"."+l]=s[l]}),s},Xp=function(e){return function(t){return t<.5?(1-e(1-t*2))/2:.5+e((t-.5)*2)/2}},zc=function n(e,t,i){var r=t>=1?t:1,s=(i||(e?.3:.45))/(t<1?t:1),o=s/rh*(Math.asin(1/r)||0),a=function(u){return u===1?1:r*Math.pow(2,-10*u)*B2((u-o)*s)+1},l=e==="out"?a:e==="in"?function(c){return 1-a(1-c)}:Xp(a);return s=rh/s,l.config=function(c,u){return n(e,c,u)},l},Hc=function n(e,t){t===void 0&&(t=1.70158);var i=function(o){return o?--o*o*((t+1)*o+t)+1:0},r=e==="out"?i:e==="in"?function(s){return 1-i(1-s)}:Xp(i);return r.config=function(s){return n(e,s)},r};Rn("Linear,Quad,Cubic,Quart,Quint,Strong",function(n,e){var t=e<5?e+1:e;ls(n+",Power"+(t-1),e?function(i){return Math.pow(i,t)}:function(i){return i},function(i){return 1-Math.pow(1-i,t)},function(i){return i<.5?Math.pow(i*2,t)/2:1-Math.pow((1-i)*2,t)/2})});at.Linear.easeNone=at.none=at.Linear.easeIn;ls("Elastic",zc("in"),zc("out"),zc());(function(n,e){var t=1/e,i=2*t,r=2.5*t,s=function(a){return a<t?n*a*a:a<i?n*Math.pow(a-1.5/e,2)+.75:a<r?n*(a-=2.25/e)*a+.9375:n*Math.pow(a-2.625/e,2)+.984375};ls("Bounce",function(o){return 1-s(1-o)},s)})(7.5625,2.75);ls("Expo",function(n){return n?Math.pow(2,10*(n-1)):0});ls("Circ",function(n){return-(pp(1-n*n)-1)});ls("Sine",function(n){return n===1?1:-k2(n*F2)+1});ls("Back",Hc("in"),Hc("out"),Hc());at.SteppedEase=at.steps=Wn.SteppedEase={config:function(e,t){e===void 0&&(e=1);var i=1/e,r=e+(t?0:1),s=t?1:0,o=1-At;return function(a){return((r*pa(0,o,a)|0)+s)*i}}};io.ease=at["quad.out"];Rn("onComplete,onUpdate,onStart,onRepeat,onReverseComplete,onInterrupt",function(n){return Jh+=n+","+n+"Params,"});var qp=function(e,t){this.id=O2++,e._gsap=this,this.target=e,this.harness=t,this.get=t?t.get:bp,this.set=t?t.getSetter:rf},sa=function(){function n(t){this.vars=t,this._delay=+t.delay||0,(this._repeat=t.repeat===1/0?-2:t.repeat||0)&&(this._rDelay=t.repeatDelay||0,this._yoyo=!!t.yoyo||!!t.yoyoEase),this._ts=1,so(this,+t.duration,1,1),this.data=t.data,Dt&&(this._ctx=Dt,Dt.data.push(this)),ra||zn.wake()}var e=n.prototype;return e.delay=function(i){return i||i===0?(this.parent&&this.parent.smoothChildTiming&&this.startTime(this._start+i-this._delay),this._delay=i,this):this._delay},e.duration=function(i){return arguments.length?this.totalDuration(this._repeat>0?i+(i+this._rDelay)*this._repeat:i):this.totalDuration()&&this._dur},e.totalDuration=function(i){return arguments.length?(this._dirty=0,so(this,this._repeat<0?i:(i-this._repeat*this._rDelay)/(this._repeat+1))):this._tDur},e.totalTime=function(i,r){if(oo(),!arguments.length)return this._tTime;var s=this._dp;if(s&&s.smoothChildTiming&&this._ts){for(Ql(this,i),!s._dp||s.parent||Cp(s,this);s&&s.parent;)s.parent._time!==s._start+(s._ts>=0?s._tTime/s._ts:(s.totalDuration()-s._tTime)/-s._ts)&&s.totalTime(s._tTime,!0),s=s.parent;!this.parent&&this._dp.autoRemoveChildren&&(this._ts>0&&i<this._tDur||this._ts<0&&i>0||!this._tDur&&!i)&&vi(this._dp,this,this._start-this._delay)}return(this._tTime!==i||!this._dur&&!r||this._initted&&Math.abs(this._zTime)===At||!i&&!this._initted&&(this.add||this._ptLookup))&&(this._ts||(this._pTime=i),wp(this,i,r)),this},e.time=function(i,r){return arguments.length?this.totalTime(Math.min(this.totalDuration(),i+Ld(this))%(this._dur+this._rDelay)||(i?this._dur:0),r):this._time},e.totalProgress=function(i,r){return arguments.length?this.totalTime(this.totalDuration()*i,r):this.totalDuration()?Math.min(1,this._tTime/this._tDur):this.rawTime()>0?1:0},e.progress=function(i,r){return arguments.length?this.totalTime(this.duration()*(this._yoyo&&!(this.iteration()&1)?1-i:i)+Ld(this),r):this.duration()?Math.min(1,this._time/this._dur):this.rawTime()>0?1:0},e.iteration=function(i,r){var s=this.duration()+this._rDelay;return arguments.length?this.totalTime(this._time+(i-1)*s,r):this._repeat?ro(this._tTime,s)+1:1},e.timeScale=function(i,r){if(!arguments.length)return this._rts===-At?0:this._rts;if(this._rts===i)return this;var s=this.parent&&this._ts?Rl(this.parent._time,this):this._tTime;return this._rts=+i||0,this._ts=this._ps||i===-At?0:this._rts,this.totalTime(pa(-Math.abs(this._delay),this._tDur,s),r!==!1),Jl(this),q2(this)},e.paused=function(i){return arguments.length?(this._ps!==i&&(this._ps=i,i?(this._pTime=this._tTime||Math.max(-this._delay,this.rawTime()),this._ts=this._act=0):(oo(),this._ts=this._rts,this.totalTime(this.parent&&!this.parent.smoothChildTiming?this.rawTime():this._tTime||this._pTime,this.progress()===1&&Math.abs(this._zTime)!==At&&(this._tTime-=At)))),this):this._ps},e.startTime=function(i){if(arguments.length){this._start=i;var r=this.parent||this._dp;return r&&(r._sort||!this.parent)&&vi(r,this,i-this._delay),this}return this._start},e.endTime=function(i){return this._start+(Cn(i)?this.totalDuration():this.duration())/Math.abs(this._ts||1)},e.rawTime=function(i){var r=this.parent||this._dp;return r?i&&(!this._ts||this._repeat&&this._time&&this.totalProgress()<1)?this._tTime%(this._dur+this._rDelay):this._ts?Rl(r.rawTime(i),this):this._tTime:this._tTime},e.revert=function(i){i===void 0&&(i=G2);var r=pn;return pn=i,(this._initted||this._startAt)&&(this.timeline&&this.timeline.revert(i),this.totalTime(-.01,i.suppressEvents)),this.data!=="nested"&&i.kill!==!1&&this.kill(),pn=r,this},e.globalTime=function(i){for(var r=this,s=arguments.length?i:r.rawTime();r;)s=r._start+s/(Math.abs(r._ts)||1),r=r._dp;return!this.parent&&this._sat?this._sat.globalTime(i):s},e.repeat=function(i){return arguments.length?(this._repeat=i===1/0?-2:i,Dd(this)):this._repeat===-2?1/0:this._repeat},e.repeatDelay=function(i){if(arguments.length){var r=this._time;return this._rDelay=i,Dd(this),r?this.time(r):this}return this._rDelay},e.yoyo=function(i){return arguments.length?(this._yoyo=i,this):this._yoyo},e.seek=function(i,r){return this.totalTime(Kn(this,i),Cn(r))},e.restart=function(i,r){return this.play().totalTime(i?-this._delay:0,Cn(r))},e.play=function(i,r){return i!=null&&this.seek(i,r),this.reversed(!1).paused(!1)},e.reverse=function(i,r){return i!=null&&this.seek(i||this.totalDuration(),r),this.reversed(!0).paused(!1)},e.pause=function(i,r){return i!=null&&this.seek(i,r),this.paused(!0)},e.resume=function(){return this.paused(!1)},e.reversed=function(i){return arguments.length?(!!i!==this.reversed()&&this.timeScale(-this._rts||(i?-At:0)),this):this._rts<0},e.invalidate=function(){return this._initted=this._act=0,this._zTime=-At,this},e.isActive=function(){var i=this.parent||this._dp,r=this._start,s;return!!(!i||this._ts&&this._initted&&i.isActive()&&(s=i.rawTime(!0))>=r&&s<this.endTime(!0)-At)},e.eventCallback=function(i,r,s){var o=this.vars;return arguments.length>1?(r?(o[i]=r,s&&(o[i+"Params"]=s),i==="onUpdate"&&(this._onUpdate=r)):delete o[i],this):o[i]},e.then=function(i){var r=this;return new Promise(function(s){var o=Bt(i)?i:Tp,a=function(){var c=r.then;r.then=null,Bt(o)&&(o=o(r))&&(o.then||o===r)&&(r.then=c),s(o),r.then=c};r._initted&&r.totalProgress()===1&&r._ts>=0||!r._tTime&&r._ts<0?a():r._prom=a})},e.kill=function(){Fo(this)},n}();ei(sa.prototype,{_time:0,_start:0,_end:0,_tTime:0,_tDur:0,_dirty:0,_repeat:0,_yoyo:!1,parent:null,_initted:!1,_rDelay:0,_ts:1,_dp:0,ratio:0,_zTime:-At,_prom:0,_ps:!1,_rts:1});var xn=function(n){dp(e,n);function e(i,r){var s;return i===void 0&&(i={}),s=n.call(this,i)||this,s.labels={},s.smoothChildTiming=!!i.smoothChildTiming,s.autoRemoveChildren=!!i.autoRemoveChildren,s._sort=Cn(i.sortChildren),Nt&&vi(i.parent||Nt,Ui(s),r),i.reversed&&s.reverse(),i.paused&&s.paused(!0),i.scrollTrigger&&Rp(Ui(s),i.scrollTrigger),s}var t=e.prototype;return t.to=function(r,s,o){return $o(0,arguments,this),this},t.from=function(r,s,o){return $o(1,arguments,this),this},t.fromTo=function(r,s,o,a){return $o(2,arguments,this),this},t.set=function(r,s,o){return s.duration=0,s.parent=this,qo(s).repeatDelay||(s.repeat=0),s.immediateRender=!!s.immediateRender,new qt(r,s,Kn(this,o),1),this},t.call=function(r,s,o){return vi(this,qt.delayedCall(0,r,s),o)},t.staggerTo=function(r,s,o,a,l,c,u){return o.duration=s,o.stagger=o.stagger||a,o.onComplete=c,o.onCompleteParams=u,o.parent=this,new qt(r,o,Kn(this,l)),this},t.staggerFrom=function(r,s,o,a,l,c,u){return o.runBackwards=1,qo(o).immediateRender=Cn(o.immediateRender),this.staggerTo(r,s,o,a,l,c,u)},t.staggerFromTo=function(r,s,o,a,l,c,u,h){return a.startAt=o,qo(a).immediateRender=Cn(a.immediateRender),this.staggerTo(r,s,a,l,c,u,h)},t.render=function(r,s,o){var a=this._time,l=this._dirty?this.totalDuration():this._tDur,c=this._dur,u=r<=0?0:nn(r),h=this._zTime<0!=r<0&&(this._initted||!c),f,d,v,g,p,m,x,_,y,C,M,w;if(this!==Nt&&u>l&&r>=0&&(u=l),u!==this._tTime||o||h){if(a!==this._time&&c&&(u+=this._time-a,r+=this._time-a),f=u,y=this._start,_=this._ts,m=!_,h&&(c||(a=this._zTime),(r||!s)&&(this._zTime=r)),this._repeat){if(M=this._yoyo,p=c+this._rDelay,this._repeat<-1&&r<0)return this.totalTime(p*100+r,s,o);if(f=nn(u%p),u===l?(g=this._repeat,f=c):(g=~~(u/p),g&&g===u/p&&(f=c,g--),f>c&&(f=c)),C=ro(this._tTime,p),!a&&this._tTime&&C!==g&&this._tTime-C*p-this._dur<=0&&(C=g),M&&g&1&&(f=c-f,w=1),g!==C&&!this._lock){var P=M&&C&1,I=P===(M&&g&1);if(g<C&&(P=!P),a=P?0:u%c?c:u,this._lock=1,this.render(a||(w?0:nn(g*p)),s,!c)._lock=0,this._tTime=u,!s&&this.parent&&Gn(this,"onRepeat"),this.vars.repeatRefresh&&!w&&(this.invalidate()._lock=1),a&&a!==this._time||m!==!this._ts||this.vars.onRepeat&&!this.parent&&!this._act)return this;if(c=this._dur,l=this._tDur,I&&(this._lock=2,a=P?c:-1e-4,this.render(a,!0),this.vars.repeatRefresh&&!w&&this.invalidate()),this._lock=0,!this._ts&&!m)return this;Wp(this,w)}}if(this._hasPause&&!this._forcing&&this._lock<2&&(x=j2(this,nn(a),nn(f)),x&&(u-=f-(f=x._start))),this._tTime=u,this._time=f,this._act=!_,this._initted||(this._onUpdate=this.vars.onUpdate,this._initted=1,this._zTime=r,a=0),!a&&f&&!s&&!g&&(Gn(this,"onStart"),this._tTime!==u))return this;if(f>=a&&r>=0)for(d=this._first;d;){if(v=d._next,(d._act||f>=d._start)&&d._ts&&x!==d){if(d.parent!==this)return this.render(r,s,o);if(d.render(d._ts>0?(f-d._start)*d._ts:(d._dirty?d.totalDuration():d._tDur)+(f-d._start)*d._ts,s,o),f!==this._time||!this._ts&&!m){x=0,v&&(u+=this._zTime=-At);break}}d=v}else{d=this._last;for(var S=r<0?r:f;d;){if(v=d._prev,(d._act||S<=d._end)&&d._ts&&x!==d){if(d.parent!==this)return this.render(r,s,o);if(d.render(d._ts>0?(S-d._start)*d._ts:(d._dirty?d.totalDuration():d._tDur)+(S-d._start)*d._ts,s,o||pn&&(d._initted||d._startAt)),f!==this._time||!this._ts&&!m){x=0,v&&(u+=this._zTime=S?-At:At);break}}d=v}}if(x&&!s&&(this.pause(),x.render(f>=a?0:-At)._zTime=f>=a?1:-1,this._ts))return this._start=y,Jl(this),this.render(r,s,o);this._onUpdate&&!s&&Gn(this,"onUpdate",!0),(u===l&&this._tTime>=this.totalDuration()||!u&&a)&&(y===this._start||Math.abs(_)!==Math.abs(this._ts))&&(this._lock||((r||!c)&&(u===l&&this._ts>0||!u&&this._ts<0)&&yr(this,1),!s&&!(r<0&&!a)&&(u||a||!l)&&(Gn(this,u===l&&r>=0?"onComplete":"onReverseComplete",!0),this._prom&&!(u<l&&this.timeScale()>0)&&this._prom())))}return this},t.add=function(r,s){var o=this;if(Gi(s)||(s=Kn(this,s,r)),!(r instanceof sa)){if(mn(r))return r.forEach(function(a){return o.add(a,s)}),this;if(rn(r))return this.addLabel(r,s);if(Bt(r))r=qt.delayedCall(0,r);else return this}return this!==r?vi(this,r,s):this},t.getChildren=function(r,s,o,a){r===void 0&&(r=!0),s===void 0&&(s=!0),o===void 0&&(o=!0),a===void 0&&(a=-Jn);for(var l=[],c=this._first;c;)c._start>=a&&(c instanceof qt?s&&l.push(c):(o&&l.push(c),r&&l.push.apply(l,c.getChildren(!0,s,o)))),c=c._next;return l},t.getById=function(r){for(var s=this.getChildren(1,1,1),o=s.length;o--;)if(s[o].vars.id===r)return s[o]},t.remove=function(r){return rn(r)?this.removeLabel(r):Bt(r)?this.killTweensOf(r):(Zl(this,r),r===this._recent&&(this._recent=this._last),$r(this))},t.totalTime=function(r,s){return arguments.length?(this._forcing=1,!this._dp&&this._ts&&(this._start=nn(zn.time-(this._ts>0?r/this._ts:(this.totalDuration()-r)/-this._ts))),n.prototype.totalTime.call(this,r,s),this._forcing=0,this):this._tTime},t.addLabel=function(r,s){return this.labels[r]=Kn(this,s),this},t.removeLabel=function(r){return delete this.labels[r],this},t.addPause=function(r,s,o){var a=qt.delayedCall(0,s||na,o);return a.data="isPause",this._hasPause=1,vi(this,a,Kn(this,r))},t.removePause=function(r){var s=this._first;for(r=Kn(this,r);s;)s._start===r&&s.data==="isPause"&&yr(s),s=s._next},t.killTweensOf=function(r,s,o){for(var a=this.getTweensOf(r,o),l=a.length;l--;)cr!==a[l]&&a[l].kill(r,s);return this},t.getTweensOf=function(r,s){for(var o=[],a=Qn(r),l=this._first,c=Gi(s),u;l;)l instanceof qt?V2(l._targets,a)&&(c?(!cr||l._initted&&l._ts)&&l.globalTime(0)<=s&&l.globalTime(l.totalDuration())>s:!s||l.isActive())&&o.push(l):(u=l.getTweensOf(a,s)).length&&o.push.apply(o,u),l=l._next;return o},t.tweenTo=function(r,s){s=s||{};var o=this,a=Kn(o,r),l=s,c=l.startAt,u=l.onStart,h=l.onStartParams,f=l.immediateRender,d,v=qt.to(o,ei({ease:s.ease||"none",lazy:!1,immediateRender:!1,time:a,overwrite:"auto",duration:s.duration||Math.abs((a-(c&&"time"in c?c.time:o._time))/o.timeScale())||At,onStart:function(){if(o.pause(),!d){var p=s.duration||Math.abs((a-(c&&"time"in c?c.time:o._time))/o.timeScale());v._dur!==p&&so(v,p,0,1).render(v._time,!0,!0),d=1}u&&u.apply(v,h||[])}},s));return f?v.render(0):v},t.tweenFromTo=function(r,s,o){return this.tweenTo(s,ei({startAt:{time:Kn(this,r)}},o))},t.recent=function(){return this._recent},t.nextLabel=function(r){return r===void 0&&(r=this._time),Id(this,Kn(this,r))},t.previousLabel=function(r){return r===void 0&&(r=this._time),Id(this,Kn(this,r),1)},t.currentLabel=function(r){return arguments.length?this.seek(r,!0):this.previousLabel(this._time+At)},t.shiftChildren=function(r,s,o){o===void 0&&(o=0);for(var a=this._first,l=this.labels,c;a;)a._start>=o&&(a._start+=r,a._end+=r),a=a._next;if(s)for(c in l)l[c]>=o&&(l[c]+=r);return $r(this)},t.invalidate=function(r){var s=this._first;for(this._lock=0;s;)s.invalidate(r),s=s._next;return n.prototype.invalidate.call(this,r)},t.clear=function(r){r===void 0&&(r=!0);for(var s=this._first,o;s;)o=s._next,this.remove(s),s=o;return this._dp&&(this._time=this._tTime=this._pTime=0),r&&(this.labels={}),$r(this)},t.totalDuration=function(r){var s=0,o=this,a=o._last,l=Jn,c,u,h;if(arguments.length)return o.timeScale((o._repeat<0?o.duration():o.totalDuration())/(o.reversed()?-r:r));if(o._dirty){for(h=o.parent;a;)c=a._prev,a._dirty&&a.totalDuration(),u=a._start,u>l&&o._sort&&a._ts&&!o._lock?(o._lock=1,vi(o,a,u-a._delay,1)._lock=0):l=u,u<0&&a._ts&&(s-=u,(!h&&!o._dp||h&&h.smoothChildTiming)&&(o._start+=u/o._ts,o._time-=u,o._tTime-=u),o.shiftChildren(-u,!1,-1/0),l=0),a._end>s&&a._ts&&(s=a._end),a=c;so(o,o===Nt&&o._time>s?o._time:s,1,1),o._dirty=0}return o._tDur},e.updateRoot=function(r){if(Nt._ts&&(wp(Nt,Rl(r,Nt)),Mp=zn.frame),zn.frame>=Rd){Rd+=Vn.autoSleep||120;var s=Nt._first;if((!s||!s._ts)&&Vn.autoSleep&&zn._listeners.length<2){for(;s&&!s._ts;)s=s._next;s||zn.sleep()}}},e}(sa);ei(xn.prototype,{_lock:0,_hasPause:0,_forcing:0});var fS=function(e,t,i,r,s,o,a){var l=new Pn(this._pt,e,t,0,1,Jp,null,s),c=0,u=0,h,f,d,v,g,p,m,x;for(l.b=i,l.e=r,i+="",r+="",(m=~r.indexOf("random("))&&(r=ia(r)),o&&(x=[i,r],o(x,e,t),i=x[0],r=x[1]),f=i.match(Oc)||[];h=Oc.exec(r);)v=h[0],g=r.substring(c,h.index),d?d=(d+1)%5:g.substr(-5)==="rgba("&&(d=1),v!==f[u++]&&(p=parseFloat(f[u-1])||0,l._pt={_next:l._pt,p:g||u===1?g:",",s:p,c:v.charAt(1)==="="?Ys(p,v)-p:parseFloat(v)-p,m:d&&d<4?Math.round:0},c=Oc.lastIndex);return l.c=c<r.length?r.substring(c,r.length):"",l.fp=a,(vp.test(r)||m)&&(l.e=0),this._pt=l,l},ef=function(e,t,i,r,s,o,a,l,c,u){Bt(r)&&(r=r(s||0,e,o));var h=e[t],f=i!=="get"?i:Bt(h)?c?e[t.indexOf("set")||!Bt(e["get"+t.substr(3)])?t:"get"+t.substr(3)](c):e[t]():h,d=Bt(h)?c?vS:jp:nf,v;if(rn(r)&&(~r.indexOf("random(")&&(r=ia(r)),r.charAt(1)==="="&&(v=Ys(f,r)+(fn(f)||0),(v||v===0)&&(r=v))),!u||f!==r||dh)return!isNaN(f*r)&&r!==""?(v=new Pn(this._pt,e,t,+f||0,r-(f||0),typeof h=="boolean"?xS:Zp,0,d),c&&(v.fp=c),a&&v.modifier(a,this,e),this._pt=v):(!h&&!(t in e)&&jh(t,r),fS.call(this,e,t,f,r,d,l||Vn.stringFilter,c))},dS=function(e,t,i,r,s){if(Bt(e)&&(e=Yo(e,s,t,i,r)),!bi(e)||e.style&&e.nodeType||mn(e)||mp(e))return rn(e)?Yo(e,s,t,i,r):e;var o={},a;for(a in e)o[a]=Yo(e[a],s,t,i,r);return o},$p=function(e,t,i,r,s,o){var a,l,c,u;if(On[e]&&(a=new On[e]).init(s,a.rawVars?t[e]:dS(t[e],r,s,o,i),i,r,o)!==!1&&(i._pt=l=new Pn(i._pt,s,e,0,1,a.render,a,0,a.priority),i!==Hs))for(c=i._ptLookup[i._targets.indexOf(s)],u=a._props.length;u--;)c[a._props[u]]=l;return a},cr,dh,tf=function n(e,t,i){var r=e.vars,s=r.ease,o=r.startAt,a=r.immediateRender,l=r.lazy,c=r.onUpdate,u=r.runBackwards,h=r.yoyoEase,f=r.keyframes,d=r.autoRevert,v=e._dur,g=e._startAt,p=e._targets,m=e.parent,x=m&&m.data==="nested"?m.vars.targets:p,_=e._overwrite==="auto"&&!qh,y=e.timeline,C,M,w,P,I,S,b,N,R,H,T,k,Z;if(y&&(!f||!s)&&(s="none"),e._ease=Yr(s,io.ease),e._yEase=h?Vp(Yr(h===!0?s:h,io.ease)):0,h&&e._yoyo&&!e._repeat&&(h=e._yEase,e._yEase=e._ease,e._ease=h),e._from=!y&&!!r.runBackwards,!y||f&&!r.stagger){if(N=p[0]?qr(p[0]).harness:0,k=N&&r[N.prop],C=Cl(r,Zh),g&&(g._zTime<0&&g.progress(1),t<0&&u&&a&&!d?g.render(-1,!0):g.revert(u&&v?dl:H2),g._lazy=0),o){if(yr(e._startAt=qt.set(p,ei({data:"isStart",overwrite:!1,parent:m,immediateRender:!0,lazy:!g&&Cn(l),startAt:null,delay:0,onUpdate:c&&function(){return Gn(e,"onUpdate")},stagger:0},o))),e._startAt._dp=0,e._startAt._sat=e,t<0&&(pn||!a&&!d)&&e._startAt.revert(dl),a&&v&&t<=0&&i<=0){t&&(e._zTime=t);return}}else if(u&&v&&!g){if(t&&(a=!1),w=ei({overwrite:!1,data:"isFromStart",lazy:a&&!g&&Cn(l),immediateRender:a,stagger:0,parent:m},C),k&&(w[N.prop]=k),yr(e._startAt=qt.set(p,w)),e._startAt._dp=0,e._startAt._sat=e,t<0&&(pn?e._startAt.revert(dl):e._startAt.render(-1,!0)),e._zTime=t,!a)n(e._startAt,At,At);else if(!t)return}for(e._pt=e._ptCache=0,l=v&&Cn(l)||l&&!v,M=0;M<p.length;M++){if(I=p[M],b=I._gsap||Qh(p)[M]._gsap,e._ptLookup[M]=H={},ah[b.id]&&mr.length&&Al(),T=x===p?M:x.indexOf(I),N&&(R=new N).init(I,k||C,e,T,x)!==!1&&(e._pt=P=new Pn(e._pt,I,R.name,0,1,R.render,R,0,R.priority),R._props.forEach(function(K){H[K]=P}),R.priority&&(S=1)),!N||k)for(w in C)On[w]&&(R=$p(w,C,e,T,I,x))?R.priority&&(S=1):H[w]=P=ef.call(e,I,w,"get",C[w],T,x,0,r.stringFilter);e._op&&e._op[M]&&e.kill(I,e._op[M]),_&&e._pt&&(cr=e,Nt.killTweensOf(I,H,e.globalTime(t)),Z=!e.parent,cr=0),e._pt&&l&&(ah[b.id]=1)}S&&Qp(e),e._onInit&&e._onInit(e)}e._onUpdate=c,e._initted=(!e._op||e._pt)&&!Z,f&&t<=0&&y.render(Jn,!0,!0)},pS=function(e,t,i,r,s,o,a,l){var c=(e._pt&&e._ptCache||(e._ptCache={}))[t],u,h,f,d;if(!c)for(c=e._ptCache[t]=[],f=e._ptLookup,d=e._targets.length;d--;){if(u=f[d][t],u&&u.d&&u.d._pt)for(u=u.d._pt;u&&u.p!==t&&u.fp!==t;)u=u._next;if(!u)return dh=1,e.vars[t]="+=0",tf(e,a),dh=0,l?ta(t+" not eligible for reset"):1;c.push(u)}for(d=c.length;d--;)h=c[d],u=h._pt||h,u.s=(r||r===0)&&!s?r:u.s+(r||0)+o*u.c,u.c=i-u.s,h.e&&(h.e=zt(i)+fn(h.e)),h.b&&(h.b=u.s+fn(h.b))},mS=function(e,t){var i=e[0]?qr(e[0]).harness:0,r=i&&i.aliases,s,o,a,l;if(!r)return t;s=ts({},t);for(o in r)if(o in s)for(l=r[o].split(","),a=l.length;a--;)s[l[a]]=s[o];return s},gS=function(e,t,i,r){var s=t.ease||r||"power1.inOut",o,a;if(mn(t))a=i[e]||(i[e]=[]),t.forEach(function(l,c){return a.push({t:c/(t.length-1)*100,v:l,e:s})});else for(o in t)a=i[o]||(i[o]=[]),o==="ease"||a.push({t:parseFloat(e),v:t[o],e:s})},Yo=function(e,t,i,r,s){return Bt(e)?e.call(t,i,r,s):rn(e)&&~e.indexOf("random(")?ia(e):e},Yp=Jh+"repeat,repeatDelay,yoyo,repeatRefresh,yoyoEase,autoRevert",Kp={};Rn(Yp+",id,stagger,delay,duration,paused,scrollTrigger",function(n){return Kp[n]=1});var qt=function(n){dp(e,n);function e(i,r,s,o){var a;typeof r=="number"&&(s.duration=r,r=s,s=null),a=n.call(this,o?r:qo(r))||this;var l=a.vars,c=l.duration,u=l.delay,h=l.immediateRender,f=l.stagger,d=l.overwrite,v=l.keyframes,g=l.defaults,p=l.scrollTrigger,m=l.yoyoEase,x=r.parent||Nt,_=(mn(i)||mp(i)?Gi(i[0]):"length"in r)?[i]:Qn(i),y,C,M,w,P,I,S,b;if(a._targets=_.length?Qh(_):ta("GSAP target "+i+" not found. https://gsap.com",!Vn.nullTargetWarn)||[],a._ptLookup=[],a._overwrite=d,v||f||$a(c)||$a(u)){if(r=a.vars,y=a.timeline=new xn({data:"nested",defaults:g||{},targets:x&&x.data==="nested"?x.vars.targets:_}),y.kill(),y.parent=y._dp=Ui(a),y._start=0,f||$a(c)||$a(u)){if(w=_.length,S=f&&Ip(f),bi(f))for(P in f)~Yp.indexOf(P)&&(b||(b={}),b[P]=f[P]);for(C=0;C<w;C++)M=Cl(r,Kp),M.stagger=0,m&&(M.yoyoEase=m),b&&ts(M,b),I=_[C],M.duration=+Yo(c,Ui(a),C,I,_),M.delay=(+Yo(u,Ui(a),C,I,_)||0)-a._delay,!f&&w===1&&M.delay&&(a._delay=u=M.delay,a._start+=u,M.delay=0),y.to(I,M,S?S(C,I,_):0),y._ease=at.none;y.duration()?c=u=0:a.timeline=0}else if(v){qo(ei(y.vars.defaults,{ease:"none"})),y._ease=Yr(v.ease||r.ease||"none");var N=0,R,H,T;if(mn(v))v.forEach(function(k){return y.to(_,k,">")}),y.duration();else{M={};for(P in v)P==="ease"||P==="easeEach"||gS(P,v[P],M,v.easeEach);for(P in M)for(R=M[P].sort(function(k,Z){return k.t-Z.t}),N=0,C=0;C<R.length;C++)H=R[C],T={ease:H.e,duration:(H.t-(C?R[C-1].t:0))/100*c},T[P]=H.v,y.to(_,T,N),N+=T.duration;y.duration()<c&&y.to({},{duration:c-y.duration()})}}c||a.duration(c=y.duration())}else a.timeline=0;return d===!0&&!qh&&(cr=Ui(a),Nt.killTweensOf(_),cr=0),vi(x,Ui(a),s),r.reversed&&a.reverse(),r.paused&&a.paused(!0),(h||!c&&!v&&a._start===nn(x._time)&&Cn(h)&&$2(Ui(a))&&x.data!=="nested")&&(a._tTime=-At,a.render(Math.max(0,-u)||0)),p&&Rp(Ui(a),p),a}var t=e.prototype;return t.render=function(r,s,o){var a=this._time,l=this._tDur,c=this._dur,u=r<0,h=r>l-At&&!u?l:r<At?0:r,f,d,v,g,p,m,x,_,y;if(!c)K2(this,r,s,o);else if(h!==this._tTime||!r||o||!this._initted&&this._tTime||this._startAt&&this._zTime<0!==u){if(f=h,_=this.timeline,this._repeat){if(g=c+this._rDelay,this._repeat<-1&&u)return this.totalTime(g*100+r,s,o);if(f=nn(h%g),h===l?(v=this._repeat,f=c):(v=~~(h/g),v&&v===nn(h/g)&&(f=c,v--),f>c&&(f=c)),m=this._yoyo&&v&1,m&&(y=this._yEase,f=c-f),p=ro(this._tTime,g),f===a&&!o&&this._initted&&v===p)return this._tTime=h,this;v!==p&&(_&&this._yEase&&Wp(_,m),this.vars.repeatRefresh&&!m&&!this._lock&&this._time!==g&&this._initted&&(this._lock=o=1,this.render(nn(g*v),!0).invalidate()._lock=0))}if(!this._initted){if(Pp(this,u?r:f,o,s,h))return this._tTime=0,this;if(a!==this._time&&!(o&&this.vars.repeatRefresh&&v!==p))return this;if(c!==this._dur)return this.render(r,s,o)}if(this._tTime=h,this._time=f,!this._act&&this._ts&&(this._act=1,this._lazy=0),this.ratio=x=(y||this._ease)(f/c),this._from&&(this.ratio=x=1-x),f&&!a&&!s&&!v&&(Gn(this,"onStart"),this._tTime!==h))return this;for(d=this._pt;d;)d.r(x,d.d),d=d._next;_&&_.render(r<0?r:_._dur*_._ease(f/this._dur),s,o)||this._startAt&&(this._zTime=r),this._onUpdate&&!s&&(u&&lh(this,r,s,o),Gn(this,"onUpdate")),this._repeat&&v!==p&&this.vars.onRepeat&&!s&&this.parent&&Gn(this,"onRepeat"),(h===this._tDur||!h)&&this._tTime===h&&(u&&!this._onUpdate&&lh(this,r,!0,!0),(r||!c)&&(h===this._tDur&&this._ts>0||!h&&this._ts<0)&&yr(this,1),!s&&!(u&&!a)&&(h||a||m)&&(Gn(this,h===l?"onComplete":"onReverseComplete",!0),this._prom&&!(h<l&&this.timeScale()>0)&&this._prom()))}return this},t.targets=function(){return this._targets},t.invalidate=function(r){return(!r||!this.vars.runBackwards)&&(this._startAt=0),this._pt=this._op=this._onUpdate=this._lazy=this.ratio=0,this._ptLookup=[],this.timeline&&this.timeline.invalidate(r),n.prototype.invalidate.call(this,r)},t.resetTo=function(r,s,o,a,l){ra||zn.wake(),this._ts||this.play();var c=Math.min(this._dur,(this._dp._time-this._start)*this._ts),u;return this._initted||tf(this,c),u=this._ease(c/this._dur),pS(this,r,s,o,a,u,c,l)?this.resetTo(r,s,o,a,1):(Ql(this,0),this.parent||Ap(this._dp,this,"_first","_last",this._dp._sort?"_start":0),this.render(0))},t.kill=function(r,s){if(s===void 0&&(s="all"),!r&&(!s||s==="all"))return this._lazy=this._pt=0,this.parent?Fo(this):this;if(this.timeline){var o=this.timeline.totalDuration();return this.timeline.killTweensOf(r,s,cr&&cr.vars.overwrite!==!0)._first||Fo(this),this.parent&&o!==this.timeline.totalDuration()&&so(this,this._dur*this.timeline._tDur/o,0,1),this}var a=this._targets,l=r?Qn(r):a,c=this._ptLookup,u=this._pt,h,f,d,v,g,p,m;if((!s||s==="all")&&X2(a,l))return s==="all"&&(this._pt=0),Fo(this);for(h=this._op=this._op||[],s!=="all"&&(rn(s)&&(g={},Rn(s,function(x){return g[x]=1}),s=g),s=mS(a,s)),m=a.length;m--;)if(~l.indexOf(a[m])){f=c[m],s==="all"?(h[m]=s,v=f,d={}):(d=h[m]=h[m]||{},v=s);for(g in v)p=f&&f[g],p&&((!("kill"in p.d)||p.d.kill(g)===!0)&&Zl(this,p,"_pt"),delete f[g]),d!=="all"&&(d[g]=1)}return this._initted&&!this._pt&&u&&Fo(this),this},e.to=function(r,s){return new e(r,s,arguments[2])},e.from=function(r,s){return $o(1,arguments)},e.delayedCall=function(r,s,o,a){return new e(s,0,{immediateRender:!1,lazy:!1,overwrite:!1,delay:r,onComplete:s,onReverseComplete:s,onCompleteParams:o,onReverseCompleteParams:o,callbackScope:a})},e.fromTo=function(r,s,o){return $o(2,arguments)},e.set=function(r,s){return s.duration=0,s.repeatDelay||(s.repeat=0),new e(r,s)},e.killTweensOf=function(r,s,o){return Nt.killTweensOf(r,s,o)},e}(sa);ei(qt.prototype,{_targets:[],_lazy:0,_startAt:0,_op:0,_onInit:0});Rn("staggerTo,staggerFrom,staggerFromTo",function(n){qt[n]=function(){var e=new xn,t=uh.call(arguments,0);return t.splice(n==="staggerFromTo"?5:4,0,0),e[n].apply(e,t)}});var nf=function(e,t,i){return e[t]=i},jp=function(e,t,i){return e[t](i)},vS=function(e,t,i,r){return e[t](r.fp,i)},_S=function(e,t,i){return e.setAttribute(t,i)},rf=function(e,t){return Bt(e[t])?jp:$h(e[t])&&e.setAttribute?_S:nf},Zp=function(e,t){return t.set(t.t,t.p,Math.round((t.s+t.c*e)*1e6)/1e6,t)},xS=function(e,t){return t.set(t.t,t.p,!!(t.s+t.c*e),t)},Jp=function(e,t){var i=t._pt,r="";if(!e&&t.b)r=t.b;else if(e===1&&t.e)r=t.e;else{for(;i;)r=i.p+(i.m?i.m(i.s+i.c*e):Math.round((i.s+i.c*e)*1e4)/1e4)+r,i=i._next;r+=t.c}t.set(t.t,t.p,r,t)},sf=function(e,t){for(var i=t._pt;i;)i.r(e,i.d),i=i._next},yS=function(e,t,i,r){for(var s=this._pt,o;s;)o=s._next,s.p===r&&s.modifier(e,t,i),s=o},SS=function(e){for(var t=this._pt,i,r;t;)r=t._next,t.p===e&&!t.op||t.op===e?Zl(this,t,"_pt"):t.dep||(i=1),t=r;return!i},MS=function(e,t,i,r){r.mSet(e,t,r.m.call(r.tween,i,r.mt),r)},Qp=function(e){for(var t=e._pt,i,r,s,o;t;){for(i=t._next,r=s;r&&r.pr>t.pr;)r=r._next;(t._prev=r?r._prev:o)?t._prev._next=t:s=t,(t._next=r)?r._prev=t:o=t,t=i}e._pt=s},Pn=function(){function n(t,i,r,s,o,a,l,c,u){this.t=i,this.s=s,this.c=o,this.p=r,this.r=a||Zp,this.d=l||this,this.set=c||nf,this.pr=u||0,this._next=t,t&&(t._prev=this)}var e=n.prototype;return e.modifier=function(i,r,s){this.mSet=this.mSet||this.set,this.set=MS,this.m=i,this.mt=s,this.tween=r},n}();Rn(Jh+"parent,duration,ease,delay,overwrite,runBackwards,startAt,yoyo,immediateRender,repeat,repeatDelay,data,paused,reversed,lazy,callbackScope,stringFilter,id,yoyoEase,stagger,inherit,repeatRefresh,keyframes,autoRevert,scrollTrigger",function(n){return Zh[n]=1});Wn.TweenMax=Wn.TweenLite=qt;Wn.TimelineLite=Wn.TimelineMax=xn;Nt=new xn({sortChildren:!1,defaults:io,autoRemoveChildren:!0,id:"root",smoothChildTiming:!0});Vn.stringFilter=Gp;var Kr=[],ml={},bS=[],Nd=0,wS=0,Gc=function(e){return(ml[e]||bS).map(function(t){return t()})},ph=function(){var e=Date.now(),t=[];e-Nd>2&&(Gc("matchMediaInit"),Kr.forEach(function(i){var r=i.queries,s=i.conditions,o,a,l,c;for(a in r)o=mi.matchMedia(r[a]).matches,o&&(l=1),o!==s[a]&&(s[a]=o,c=1);c&&(i.revert(),l&&t.push(i))}),Gc("matchMediaRevert"),t.forEach(function(i){return i.onMatch(i,function(r){return i.add(null,r)})}),Nd=e,Gc("matchMedia"))},em=function(){function n(t,i){this.selector=i&&hh(i),this.data=[],this._r=[],this.isReverted=!1,this.id=wS++,t&&this.add(t)}var e=n.prototype;return e.add=function(i,r,s){Bt(i)&&(s=r,r=i,i=Bt);var o=this,a=function(){var c=Dt,u=o.selector,h;return c&&c!==o&&c.data.push(o),s&&(o.selector=hh(s)),Dt=o,h=r.apply(o,arguments),Bt(h)&&o._r.push(h),Dt=c,o.selector=u,o.isReverted=!1,h};return o.last=a,i===Bt?a(o,function(l){return o.add(null,l)}):i?o[i]=a:a},e.ignore=function(i){var r=Dt;Dt=null,i(this),Dt=r},e.getTweens=function(){var i=[];return this.data.forEach(function(r){return r instanceof n?i.push.apply(i,r.getTweens()):r instanceof qt&&!(r.parent&&r.parent.data==="nested")&&i.push(r)}),i},e.clear=function(){this._r.length=this.data.length=0},e.kill=function(i,r){var s=this;if(i?function(){for(var a=s.getTweens(),l=s.data.length,c;l--;)c=s.data[l],c.data==="isFlip"&&(c.revert(),c.getChildren(!0,!0,!1).forEach(function(u){return a.splice(a.indexOf(u),1)}));for(a.map(function(u){return{g:u._dur||u._delay||u._sat&&!u._sat.vars.immediateRender?u.globalTime(0):-1/0,t:u}}).sort(function(u,h){return h.g-u.g||-1/0}).forEach(function(u){return u.t.revert(i)}),l=s.data.length;l--;)c=s.data[l],c instanceof xn?c.data!=="nested"&&(c.scrollTrigger&&c.scrollTrigger.revert(),c.kill()):!(c instanceof qt)&&c.revert&&c.revert(i);s._r.forEach(function(u){return u(i,s)}),s.isReverted=!0}():this.data.forEach(function(a){return a.kill&&a.kill()}),this.clear(),r)for(var o=Kr.length;o--;)Kr[o].id===this.id&&Kr.splice(o,1)},e.revert=function(i){this.kill(i||{})},n}(),ES=function(){function n(t){this.contexts=[],this.scope=t,Dt&&Dt.data.push(this)}var e=n.prototype;return e.add=function(i,r,s){bi(i)||(i={matches:i});var o=new em(0,s||this.scope),a=o.conditions={},l,c,u;Dt&&!o.selector&&(o.selector=Dt.selector),this.contexts.push(o),r=o.add("onMatch",r),o.queries=i;for(c in i)c==="all"?u=1:(l=mi.matchMedia(i[c]),l&&(Kr.indexOf(o)<0&&Kr.push(o),(a[c]=l.matches)&&(u=1),l.addListener?l.addListener(ph):l.addEventListener("change",ph)));return u&&r(o,function(h){return o.add(null,h)}),this},e.revert=function(i){this.kill(i||{})},e.kill=function(i){this.contexts.forEach(function(r){return r.kill(i,!0)})},n}(),Pl={registerPlugin:function(){for(var e=arguments.length,t=new Array(e),i=0;i<e;i++)t[i]=arguments[i];t.forEach(function(r){return Bp(r)})},timeline:function(e){return new xn(e)},getTweensOf:function(e,t){return Nt.getTweensOf(e,t)},getProperty:function(e,t,i,r){rn(e)&&(e=Qn(e)[0]);var s=qr(e||{}).get,o=i?Tp:Ep;return i==="native"&&(i=""),e&&(t?o((On[t]&&On[t].get||s)(e,t,i,r)):function(a,l,c){return o((On[a]&&On[a].get||s)(e,a,l,c))})},quickSetter:function(e,t,i){if(e=Qn(e),e.length>1){var r=e.map(function(u){return Ht.quickSetter(u,t,i)}),s=r.length;return function(u){for(var h=s;h--;)r[h](u)}}e=e[0]||{};var o=On[t],a=qr(e),l=a.harness&&(a.harness.aliases||{})[t]||t,c=o?function(u){var h=new o;Hs._pt=0,h.init(e,i?u+i:u,Hs,0,[e]),h.render(1,h),Hs._pt&&sf(1,Hs)}:a.set(e,l);return o?c:function(u){return c(e,l,i?u+i:u,a,1)}},quickTo:function(e,t,i){var r,s=Ht.to(e,ts((r={},r[t]="+=0.1",r.paused=!0,r),i||{})),o=function(l,c,u){return s.resetTo(t,l,c,u)};return o.tween=s,o},isTweening:function(e){return Nt.getTweensOf(e,!0).length>0},defaults:function(e){return e&&e.ease&&(e.ease=Yr(e.ease,io.ease)),Pd(io,e||{})},config:function(e){return Pd(Vn,e||{})},registerEffect:function(e){var t=e.name,i=e.effect,r=e.plugins,s=e.defaults,o=e.extendTimeline;(r||"").split(",").forEach(function(a){return a&&!On[a]&&!Wn[a]&&ta(t+" effect requires "+a+" plugin.")}),kc[t]=function(a,l,c){return i(Qn(a),ei(l||{},s),c)},o&&(xn.prototype[t]=function(a,l,c){return this.add(kc[t](a,bi(l)?l:(c=l)&&{},this),c)})},registerEase:function(e,t){at[e]=Yr(t)},parseEase:function(e,t){return arguments.length?Yr(e,t):at},getById:function(e){return Nt.getById(e)},exportRoot:function(e,t){e===void 0&&(e={});var i=new xn(e),r,s;for(i.smoothChildTiming=Cn(e.smoothChildTiming),Nt.remove(i),i._dp=0,i._time=i._tTime=Nt._time,r=Nt._first;r;)s=r._next,(t||!(!r._dur&&r instanceof qt&&r.vars.onComplete===r._targets[0]))&&vi(i,r,r._start-r._delay),r=s;return vi(Nt,i,0),i},context:function(e,t){return e?new em(e,t):Dt},matchMedia:function(e){return new ES(e)},matchMediaRefresh:function(){return Kr.forEach(function(e){var t=e.conditions,i,r;for(r in t)t[r]&&(t[r]=!1,i=1);i&&e.revert()})||ph()},addEventListener:function(e,t){var i=ml[e]||(ml[e]=[]);~i.indexOf(t)||i.push(t)},removeEventListener:function(e,t){var i=ml[e],r=i&&i.indexOf(t);r>=0&&i.splice(r,1)},utils:{wrap:iS,wrapYoyo:rS,distribute:Ip,random:Np,snap:Up,normalize:nS,getUnit:fn,clamp:J2,splitColor:zp,toArray:Qn,selector:hh,mapRange:Op,pipe:eS,unitize:tS,interpolate:sS,shuffle:Dp},install:yp,effects:kc,ticker:zn,updateRoot:xn.updateRoot,plugins:On,globalTimeline:Nt,core:{PropTween:Pn,globals:Sp,Tween:qt,Timeline:xn,Animation:sa,getCache:qr,_removeLinkedListItem:Zl,reverting:function(){return pn},context:function(e){return e&&Dt&&(Dt.data.push(e),e._ctx=Dt),Dt},suppressOverwrites:function(e){return qh=e}}};Rn("to,from,fromTo,delayedCall,set,killTweensOf",function(n){return Pl[n]=qt[n]});zn.add(xn.updateRoot);Hs=Pl.to({},{duration:0});var TS=function(e,t){for(var i=e._pt;i&&i.p!==t&&i.op!==t&&i.fp!==t;)i=i._next;return i},AS=function(e,t){var i=e._targets,r,s,o;for(r in t)for(s=i.length;s--;)o=e._ptLookup[s][r],o&&(o=o.d)&&(o._pt&&(o=TS(o,r)),o&&o.modifier&&o.modifier(t[r],e,i[s],r))},Vc=function(e,t){return{name:e,rawVars:1,init:function(r,s,o){o._onInit=function(a){var l,c;if(rn(s)&&(l={},Rn(s,function(u){return l[u]=1}),s=l),t){l={};for(c in s)l[c]=t(s[c]);s=l}AS(a,s)}}}},Ht=Pl.registerPlugin({name:"attr",init:function(e,t,i,r,s){var o,a,l;this.tween=i;for(o in t)l=e.getAttribute(o)||"",a=this.add(e,"setAttribute",(l||0)+"",t[o],r,s,0,0,o),a.op=o,a.b=l,this._props.push(o)},render:function(e,t){for(var i=t._pt;i;)pn?i.set(i.t,i.p,i.b,i):i.r(e,i.d),i=i._next}},{name:"endArray",init:function(e,t){for(var i=t.length;i--;)this.add(e,i,e[i]||0,t[i],0,0,0,0,0,1)}},Vc("roundProps",fh),Vc("modifiers"),Vc("snap",Up))||Pl;qt.version=xn.version=Ht.version="3.12.5";xp=1;Yh()&&oo();at.Power0;at.Power1;at.Power2;at.Power3;at.Power4;at.Linear;at.Quad;at.Cubic;at.Quart;at.Quint;at.Strong;at.Elastic;at.Back;at.SteppedEase;at.Bounce;at.Sine;at.Expo;at.Circ;/*!
 * CSSPlugin 3.12.5
 * https://gsap.com
 *
 * Copyright 2008-2024, GreenSock. All rights reserved.
 * Subject to the terms at https://gsap.com/standard-license or for
 * Club GSAP members, the agreement issued with that membership.
 * @author: Jack Doyle, jack@greensock.com
*/var Fd,ur,Ks,of,Wr,Od,af,CS=function(){return typeof window<"u"},Vi={},Br=180/Math.PI,js=Math.PI/180,Cs=Math.atan2,kd=1e8,lf=/([A-Z])/g,RS=/(left|right|width|margin|padding|x)/i,PS=/[\s,\(]\S/,xi={autoAlpha:"opacity,visibility",scale:"scaleX,scaleY",alpha:"opacity"},mh=function(e,t){return t.set(t.t,t.p,Math.round((t.s+t.c*e)*1e4)/1e4+t.u,t)},LS=function(e,t){return t.set(t.t,t.p,e===1?t.e:Math.round((t.s+t.c*e)*1e4)/1e4+t.u,t)},DS=function(e,t){return t.set(t.t,t.p,e?Math.round((t.s+t.c*e)*1e4)/1e4+t.u:t.b,t)},IS=function(e,t){var i=t.s+t.c*e;t.set(t.t,t.p,~~(i+(i<0?-.5:.5))+t.u,t)},tm=function(e,t){return t.set(t.t,t.p,e?t.e:t.b,t)},nm=function(e,t){return t.set(t.t,t.p,e!==1?t.b:t.e,t)},US=function(e,t,i){return e.style[t]=i},NS=function(e,t,i){return e.style.setProperty(t,i)},FS=function(e,t,i){return e._gsap[t]=i},OS=function(e,t,i){return e._gsap.scaleX=e._gsap.scaleY=i},kS=function(e,t,i,r,s){var o=e._gsap;o.scaleX=o.scaleY=i,o.renderTransform(s,o)},BS=function(e,t,i,r,s){var o=e._gsap;o[t]=i,o.renderTransform(s,o)},Ot="transform",Ln=Ot+"Origin",zS=function n(e,t){var i=this,r=this.target,s=r.style,o=r._gsap;if(e in Vi&&s){if(this.tfm=this.tfm||{},e!=="transform")e=xi[e]||e,~e.indexOf(",")?e.split(",").forEach(function(a){return i.tfm[a]=Fi(r,a)}):this.tfm[e]=o.x?o[e]:Fi(r,e),e===Ln&&(this.tfm.zOrigin=o.zOrigin);else return xi.transform.split(",").forEach(function(a){return n.call(i,a,t)});if(this.props.indexOf(Ot)>=0)return;o.svg&&(this.svgo=r.getAttribute("data-svg-origin"),this.props.push(Ln,t,"")),e=Ot}(s||t)&&this.props.push(e,t,s[e])},im=function(e){e.translate&&(e.removeProperty("translate"),e.removeProperty("scale"),e.removeProperty("rotate"))},HS=function(){var e=this.props,t=this.target,i=t.style,r=t._gsap,s,o;for(s=0;s<e.length;s+=3)e[s+1]?t[e[s]]=e[s+2]:e[s+2]?i[e[s]]=e[s+2]:i.removeProperty(e[s].substr(0,2)==="--"?e[s]:e[s].replace(lf,"-$1").toLowerCase());if(this.tfm){for(o in this.tfm)r[o]=this.tfm[o];r.svg&&(r.renderTransform(),t.setAttribute("data-svg-origin",this.svgo||"")),s=af(),(!s||!s.isStart)&&!i[Ot]&&(im(i),r.zOrigin&&i[Ln]&&(i[Ln]+=" "+r.zOrigin+"px",r.zOrigin=0,r.renderTransform()),r.uncache=1)}},rm=function(e,t){var i={target:e,props:[],revert:HS,save:zS};return e._gsap||Ht.core.getCache(e),t&&t.split(",").forEach(function(r){return i.save(r)}),i},sm,gh=function(e,t){var i=ur.createElementNS?ur.createElementNS((t||"http://www.w3.org/1999/xhtml").replace(/^https/,"http"),e):ur.createElement(e);return i&&i.style?i:ur.createElement(e)},Si=function n(e,t,i){var r=getComputedStyle(e);return r[t]||r.getPropertyValue(t.replace(lf,"-$1").toLowerCase())||r.getPropertyValue(t)||!i&&n(e,ao(t)||t,1)||""},Bd="O,Moz,ms,Ms,Webkit".split(","),ao=function(e,t,i){var r=t||Wr,s=r.style,o=5;if(e in s&&!i)return e;for(e=e.charAt(0).toUpperCase()+e.substr(1);o--&&!(Bd[o]+e in s););return o<0?null:(o===3?"ms":o>=0?Bd[o]:"")+e},vh=function(){CS()&&window.document&&(Fd=window,ur=Fd.document,Ks=ur.documentElement,Wr=gh("div")||{style:{}},gh("div"),Ot=ao(Ot),Ln=Ot+"Origin",Wr.style.cssText="border-width:0;line-height:0;position:absolute;padding:0",sm=!!ao("perspective"),af=Ht.core.reverting,of=1)},Wc=function n(e){var t=gh("svg",this.ownerSVGElement&&this.ownerSVGElement.getAttribute("xmlns")||"http://www.w3.org/2000/svg"),i=this.parentNode,r=this.nextSibling,s=this.style.cssText,o;if(Ks.appendChild(t),t.appendChild(this),this.style.display="block",e)try{o=this.getBBox(),this._gsapBBox=this.getBBox,this.getBBox=n}catch{}else this._gsapBBox&&(o=this._gsapBBox());return i&&(r?i.insertBefore(this,r):i.appendChild(this)),Ks.removeChild(t),this.style.cssText=s,o},zd=function(e,t){for(var i=t.length;i--;)if(e.hasAttribute(t[i]))return e.getAttribute(t[i])},om=function(e){var t;try{t=e.getBBox()}catch{t=Wc.call(e,!0)}return t&&(t.width||t.height)||e.getBBox===Wc||(t=Wc.call(e,!0)),t&&!t.width&&!t.x&&!t.y?{x:+zd(e,["x","cx","x1"])||0,y:+zd(e,["y","cy","y1"])||0,width:0,height:0}:t},am=function(e){return!!(e.getCTM&&(!e.parentNode||e.ownerSVGElement)&&om(e))},ns=function(e,t){if(t){var i=e.style,r;t in Vi&&t!==Ln&&(t=Ot),i.removeProperty?(r=t.substr(0,2),(r==="ms"||t.substr(0,6)==="webkit")&&(t="-"+t),i.removeProperty(r==="--"?t:t.replace(lf,"-$1").toLowerCase())):i.removeAttribute(t)}},hr=function(e,t,i,r,s,o){var a=new Pn(e._pt,t,i,0,1,o?nm:tm);return e._pt=a,a.b=r,a.e=s,e._props.push(i),a},Hd={deg:1,rad:1,turn:1},GS={grid:1,flex:1},Sr=function n(e,t,i,r){var s=parseFloat(i)||0,o=(i+"").trim().substr((s+"").length)||"px",a=Wr.style,l=RS.test(t),c=e.tagName.toLowerCase()==="svg",u=(c?"client":"offset")+(l?"Width":"Height"),h=100,f=r==="px",d=r==="%",v,g,p,m;if(r===o||!s||Hd[r]||Hd[o])return s;if(o!=="px"&&!f&&(s=n(e,t,i,"px")),m=e.getCTM&&am(e),(d||o==="%")&&(Vi[t]||~t.indexOf("adius")))return v=m?e.getBBox()[l?"width":"height"]:e[u],zt(d?s/v*h:s/100*v);if(a[l?"width":"height"]=h+(f?o:r),g=~t.indexOf("adius")||r==="em"&&e.appendChild&&!c?e:e.parentNode,m&&(g=(e.ownerSVGElement||{}).parentNode),(!g||g===ur||!g.appendChild)&&(g=ur.body),p=g._gsap,p&&d&&p.width&&l&&p.time===zn.time&&!p.uncache)return zt(s/p.width*h);if(d&&(t==="height"||t==="width")){var x=e.style[t];e.style[t]=h+r,v=e[u],x?e.style[t]=x:ns(e,t)}else(d||o==="%")&&!GS[Si(g,"display")]&&(a.position=Si(e,"position")),g===e&&(a.position="static"),g.appendChild(Wr),v=Wr[u],g.removeChild(Wr),a.position="absolute";return l&&d&&(p=qr(g),p.time=zn.time,p.width=g[u]),zt(f?v*s/h:v&&s?h/v*s:0)},Fi=function(e,t,i,r){var s;return of||vh(),t in xi&&t!=="transform"&&(t=xi[t],~t.indexOf(",")&&(t=t.split(",")[0])),Vi[t]&&t!=="transform"?(s=aa(e,r),s=t!=="transformOrigin"?s[t]:s.svg?s.origin:Dl(Si(e,Ln))+" "+s.zOrigin+"px"):(s=e.style[t],(!s||s==="auto"||r||~(s+"").indexOf("calc("))&&(s=Ll[t]&&Ll[t](e,t,i)||Si(e,t)||bp(e,t)||(t==="opacity"?1:0))),i&&!~(s+"").trim().indexOf(" ")?Sr(e,t,s,i)+i:s},VS=function(e,t,i,r){if(!i||i==="none"){var s=ao(t,e,1),o=s&&Si(e,s,1);o&&o!==i?(t=s,i=o):t==="borderColor"&&(i=Si(e,"borderTopColor"))}var a=new Pn(this._pt,e.style,t,0,1,Jp),l=0,c=0,u,h,f,d,v,g,p,m,x,_,y,C;if(a.b=i,a.e=r,i+="",r+="",r==="auto"&&(g=e.style[t],e.style[t]=r,r=Si(e,t)||r,g?e.style[t]=g:ns(e,t)),u=[i,r],Gp(u),i=u[0],r=u[1],f=i.match(zs)||[],C=r.match(zs)||[],C.length){for(;h=zs.exec(r);)p=h[0],x=r.substring(l,h.index),v?v=(v+1)%5:(x.substr(-5)==="rgba("||x.substr(-5)==="hsla(")&&(v=1),p!==(g=f[c++]||"")&&(d=parseFloat(g)||0,y=g.substr((d+"").length),p.charAt(1)==="="&&(p=Ys(d,p)+y),m=parseFloat(p),_=p.substr((m+"").length),l=zs.lastIndex-_.length,_||(_=_||Vn.units[t]||y,l===r.length&&(r+=_,a.e+=_)),y!==_&&(d=Sr(e,t,g,_)||0),a._pt={_next:a._pt,p:x||c===1?x:",",s:d,c:m-d,m:v&&v<4||t==="zIndex"?Math.round:0});a.c=l<r.length?r.substring(l,r.length):""}else a.r=t==="display"&&r==="none"?nm:tm;return vp.test(r)&&(a.e=0),this._pt=a,a},Gd={top:"0%",bottom:"100%",left:"0%",right:"100%",center:"50%"},WS=function(e){var t=e.split(" "),i=t[0],r=t[1]||"50%";return(i==="top"||i==="bottom"||r==="left"||r==="right")&&(e=i,i=r,r=e),t[0]=Gd[i]||i,t[1]=Gd[r]||r,t.join(" ")},XS=function(e,t){if(t.tween&&t.tween._time===t.tween._dur){var i=t.t,r=i.style,s=t.u,o=i._gsap,a,l,c;if(s==="all"||s===!0)r.cssText="",l=1;else for(s=s.split(","),c=s.length;--c>-1;)a=s[c],Vi[a]&&(l=1,a=a==="transformOrigin"?Ln:Ot),ns(i,a);l&&(ns(i,Ot),o&&(o.svg&&i.removeAttribute("transform"),aa(i,1),o.uncache=1,im(r)))}},Ll={clearProps:function(e,t,i,r,s){if(s.data!=="isFromStart"){var o=e._pt=new Pn(e._pt,t,i,0,0,XS);return o.u=r,o.pr=-10,o.tween=s,e._props.push(i),1}}},oa=[1,0,0,1,0,0],lm={},cm=function(e){return e==="matrix(1, 0, 0, 1, 0, 0)"||e==="none"||!e},Vd=function(e){var t=Si(e,Ot);return cm(t)?oa:t.substr(7).match(gp).map(zt)},cf=function(e,t){var i=e._gsap||qr(e),r=e.style,s=Vd(e),o,a,l,c;return i.svg&&e.getAttribute("transform")?(l=e.transform.baseVal.consolidate().matrix,s=[l.a,l.b,l.c,l.d,l.e,l.f],s.join(",")==="1,0,0,1,0,0"?oa:s):(s===oa&&!e.offsetParent&&e!==Ks&&!i.svg&&(l=r.display,r.display="block",o=e.parentNode,(!o||!e.offsetParent)&&(c=1,a=e.nextElementSibling,Ks.appendChild(e)),s=Vd(e),l?r.display=l:ns(e,"display"),c&&(a?o.insertBefore(e,a):o?o.appendChild(e):Ks.removeChild(e))),t&&s.length>6?[s[0],s[1],s[4],s[5],s[12],s[13]]:s)},_h=function(e,t,i,r,s,o){var a=e._gsap,l=s||cf(e,!0),c=a.xOrigin||0,u=a.yOrigin||0,h=a.xOffset||0,f=a.yOffset||0,d=l[0],v=l[1],g=l[2],p=l[3],m=l[4],x=l[5],_=t.split(" "),y=parseFloat(_[0])||0,C=parseFloat(_[1])||0,M,w,P,I;i?l!==oa&&(w=d*p-v*g)&&(P=y*(p/w)+C*(-g/w)+(g*x-p*m)/w,I=y*(-v/w)+C*(d/w)-(d*x-v*m)/w,y=P,C=I):(M=om(e),y=M.x+(~_[0].indexOf("%")?y/100*M.width:y),C=M.y+(~(_[1]||_[0]).indexOf("%")?C/100*M.height:C)),r||r!==!1&&a.smooth?(m=y-c,x=C-u,a.xOffset=h+(m*d+x*g)-m,a.yOffset=f+(m*v+x*p)-x):a.xOffset=a.yOffset=0,a.xOrigin=y,a.yOrigin=C,a.smooth=!!r,a.origin=t,a.originIsAbsolute=!!i,e.style[Ln]="0px 0px",o&&(hr(o,a,"xOrigin",c,y),hr(o,a,"yOrigin",u,C),hr(o,a,"xOffset",h,a.xOffset),hr(o,a,"yOffset",f,a.yOffset)),e.setAttribute("data-svg-origin",y+" "+C)},aa=function(e,t){var i=e._gsap||new qp(e);if("x"in i&&!t&&!i.uncache)return i;var r=e.style,s=i.scaleX<0,o="px",a="deg",l=getComputedStyle(e),c=Si(e,Ln)||"0",u,h,f,d,v,g,p,m,x,_,y,C,M,w,P,I,S,b,N,R,H,T,k,Z,K,pe,ce,W,re,Ae,ee,F;return u=h=f=g=p=m=x=_=y=0,d=v=1,i.svg=!!(e.getCTM&&am(e)),l.translate&&((l.translate!=="none"||l.scale!=="none"||l.rotate!=="none")&&(r[Ot]=(l.translate!=="none"?"translate3d("+(l.translate+" 0 0").split(" ").slice(0,3).join(", ")+") ":"")+(l.rotate!=="none"?"rotate("+l.rotate+") ":"")+(l.scale!=="none"?"scale("+l.scale.split(" ").join(",")+") ":"")+(l[Ot]!=="none"?l[Ot]:"")),r.scale=r.rotate=r.translate="none"),w=cf(e,i.svg),i.svg&&(i.uncache?(K=e.getBBox(),c=i.xOrigin-K.x+"px "+(i.yOrigin-K.y)+"px",Z=""):Z=!t&&e.getAttribute("data-svg-origin"),_h(e,Z||c,!!Z||i.originIsAbsolute,i.smooth!==!1,w)),C=i.xOrigin||0,M=i.yOrigin||0,w!==oa&&(b=w[0],N=w[1],R=w[2],H=w[3],u=T=w[4],h=k=w[5],w.length===6?(d=Math.sqrt(b*b+N*N),v=Math.sqrt(H*H+R*R),g=b||N?Cs(N,b)*Br:0,x=R||H?Cs(R,H)*Br+g:0,x&&(v*=Math.abs(Math.cos(x*js))),i.svg&&(u-=C-(C*b+M*R),h-=M-(C*N+M*H))):(F=w[6],Ae=w[7],ce=w[8],W=w[9],re=w[10],ee=w[11],u=w[12],h=w[13],f=w[14],P=Cs(F,re),p=P*Br,P&&(I=Math.cos(-P),S=Math.sin(-P),Z=T*I+ce*S,K=k*I+W*S,pe=F*I+re*S,ce=T*-S+ce*I,W=k*-S+W*I,re=F*-S+re*I,ee=Ae*-S+ee*I,T=Z,k=K,F=pe),P=Cs(-R,re),m=P*Br,P&&(I=Math.cos(-P),S=Math.sin(-P),Z=b*I-ce*S,K=N*I-W*S,pe=R*I-re*S,ee=H*S+ee*I,b=Z,N=K,R=pe),P=Cs(N,b),g=P*Br,P&&(I=Math.cos(P),S=Math.sin(P),Z=b*I+N*S,K=T*I+k*S,N=N*I-b*S,k=k*I-T*S,b=Z,T=K),p&&Math.abs(p)+Math.abs(g)>359.9&&(p=g=0,m=180-m),d=zt(Math.sqrt(b*b+N*N+R*R)),v=zt(Math.sqrt(k*k+F*F)),P=Cs(T,k),x=Math.abs(P)>2e-4?P*Br:0,y=ee?1/(ee<0?-ee:ee):0),i.svg&&(Z=e.getAttribute("transform"),i.forceCSS=e.setAttribute("transform","")||!cm(Si(e,Ot)),Z&&e.setAttribute("transform",Z))),Math.abs(x)>90&&Math.abs(x)<270&&(s?(d*=-1,x+=g<=0?180:-180,g+=g<=0?180:-180):(v*=-1,x+=x<=0?180:-180)),t=t||i.uncache,i.x=u-((i.xPercent=u&&(!t&&i.xPercent||(Math.round(e.offsetWidth/2)===Math.round(-u)?-50:0)))?e.offsetWidth*i.xPercent/100:0)+o,i.y=h-((i.yPercent=h&&(!t&&i.yPercent||(Math.round(e.offsetHeight/2)===Math.round(-h)?-50:0)))?e.offsetHeight*i.yPercent/100:0)+o,i.z=f+o,i.scaleX=zt(d),i.scaleY=zt(v),i.rotation=zt(g)+a,i.rotationX=zt(p)+a,i.rotationY=zt(m)+a,i.skewX=x+a,i.skewY=_+a,i.transformPerspective=y+o,(i.zOrigin=parseFloat(c.split(" ")[2])||!t&&i.zOrigin||0)&&(r[Ln]=Dl(c)),i.xOffset=i.yOffset=0,i.force3D=Vn.force3D,i.renderTransform=i.svg?$S:sm?um:qS,i.uncache=0,i},Dl=function(e){return(e=e.split(" "))[0]+" "+e[1]},Xc=function(e,t,i){var r=fn(t);return zt(parseFloat(t)+parseFloat(Sr(e,"x",i+"px",r)))+r},qS=function(e,t){t.z="0px",t.rotationY=t.rotationX="0deg",t.force3D=0,um(e,t)},Ur="0deg",Ao="0px",Nr=") ",um=function(e,t){var i=t||this,r=i.xPercent,s=i.yPercent,o=i.x,a=i.y,l=i.z,c=i.rotation,u=i.rotationY,h=i.rotationX,f=i.skewX,d=i.skewY,v=i.scaleX,g=i.scaleY,p=i.transformPerspective,m=i.force3D,x=i.target,_=i.zOrigin,y="",C=m==="auto"&&e&&e!==1||m===!0;if(_&&(h!==Ur||u!==Ur)){var M=parseFloat(u)*js,w=Math.sin(M),P=Math.cos(M),I;M=parseFloat(h)*js,I=Math.cos(M),o=Xc(x,o,w*I*-_),a=Xc(x,a,-Math.sin(M)*-_),l=Xc(x,l,P*I*-_+_)}p!==Ao&&(y+="perspective("+p+Nr),(r||s)&&(y+="translate("+r+"%, "+s+"%) "),(C||o!==Ao||a!==Ao||l!==Ao)&&(y+=l!==Ao||C?"translate3d("+o+", "+a+", "+l+") ":"translate("+o+", "+a+Nr),c!==Ur&&(y+="rotate("+c+Nr),u!==Ur&&(y+="rotateY("+u+Nr),h!==Ur&&(y+="rotateX("+h+Nr),(f!==Ur||d!==Ur)&&(y+="skew("+f+", "+d+Nr),(v!==1||g!==1)&&(y+="scale("+v+", "+g+Nr),x.style[Ot]=y||"translate(0, 0)"},$S=function(e,t){var i=t||this,r=i.xPercent,s=i.yPercent,o=i.x,a=i.y,l=i.rotation,c=i.skewX,u=i.skewY,h=i.scaleX,f=i.scaleY,d=i.target,v=i.xOrigin,g=i.yOrigin,p=i.xOffset,m=i.yOffset,x=i.forceCSS,_=parseFloat(o),y=parseFloat(a),C,M,w,P,I;l=parseFloat(l),c=parseFloat(c),u=parseFloat(u),u&&(u=parseFloat(u),c+=u,l+=u),l||c?(l*=js,c*=js,C=Math.cos(l)*h,M=Math.sin(l)*h,w=Math.sin(l-c)*-f,P=Math.cos(l-c)*f,c&&(u*=js,I=Math.tan(c-u),I=Math.sqrt(1+I*I),w*=I,P*=I,u&&(I=Math.tan(u),I=Math.sqrt(1+I*I),C*=I,M*=I)),C=zt(C),M=zt(M),w=zt(w),P=zt(P)):(C=h,P=f,M=w=0),(_&&!~(o+"").indexOf("px")||y&&!~(a+"").indexOf("px"))&&(_=Sr(d,"x",o,"px"),y=Sr(d,"y",a,"px")),(v||g||p||m)&&(_=zt(_+v-(v*C+g*w)+p),y=zt(y+g-(v*M+g*P)+m)),(r||s)&&(I=d.getBBox(),_=zt(_+r/100*I.width),y=zt(y+s/100*I.height)),I="matrix("+C+","+M+","+w+","+P+","+_+","+y+")",d.setAttribute("transform",I),x&&(d.style[Ot]=I)},YS=function(e,t,i,r,s){var o=360,a=rn(s),l=parseFloat(s)*(a&&~s.indexOf("rad")?Br:1),c=l-r,u=r+c+"deg",h,f;return a&&(h=s.split("_")[1],h==="short"&&(c%=o,c!==c%(o/2)&&(c+=c<0?o:-o)),h==="cw"&&c<0?c=(c+o*kd)%o-~~(c/o)*o:h==="ccw"&&c>0&&(c=(c-o*kd)%o-~~(c/o)*o)),e._pt=f=new Pn(e._pt,t,i,r,c,LS),f.e=u,f.u="deg",e._props.push(i),f},Wd=function(e,t){for(var i in t)e[i]=t[i];return e},KS=function(e,t,i){var r=Wd({},i._gsap),s="perspective,force3D,transformOrigin,svgOrigin",o=i.style,a,l,c,u,h,f,d,v;r.svg?(c=i.getAttribute("transform"),i.setAttribute("transform",""),o[Ot]=t,a=aa(i,1),ns(i,Ot),i.setAttribute("transform",c)):(c=getComputedStyle(i)[Ot],o[Ot]=t,a=aa(i,1),o[Ot]=c);for(l in Vi)c=r[l],u=a[l],c!==u&&s.indexOf(l)<0&&(d=fn(c),v=fn(u),h=d!==v?Sr(i,l,c,v):parseFloat(c),f=parseFloat(u),e._pt=new Pn(e._pt,a,l,h,f-h,mh),e._pt.u=v||0,e._props.push(l));Wd(a,r)};Rn("padding,margin,Width,Radius",function(n,e){var t="Top",i="Right",r="Bottom",s="Left",o=(e<3?[t,i,r,s]:[t+s,t+i,r+i,r+s]).map(function(a){return e<2?n+a:"border"+a+n});Ll[e>1?"border"+n:n]=function(a,l,c,u,h){var f,d;if(arguments.length<4)return f=o.map(function(v){return Fi(a,v,c)}),d=f.join(" "),d.split(f[0]).length===5?f[0]:d;f=(u+"").split(" "),d={},o.forEach(function(v,g){return d[v]=f[g]=f[g]||f[(g-1)/2|0]}),a.init(l,d,h)}});var hm={name:"css",register:vh,targetTest:function(e){return e.style&&e.nodeType},init:function(e,t,i,r,s){var o=this._props,a=e.style,l=i.vars.startAt,c,u,h,f,d,v,g,p,m,x,_,y,C,M,w,P;of||vh(),this.styles=this.styles||rm(e),P=this.styles.props,this.tween=i;for(g in t)if(g!=="autoRound"&&(u=t[g],!(On[g]&&$p(g,t,i,r,e,s)))){if(d=typeof u,v=Ll[g],d==="function"&&(u=u.call(i,r,e,s),d=typeof u),d==="string"&&~u.indexOf("random(")&&(u=ia(u)),v)v(this,e,g,u,i)&&(w=1);else if(g.substr(0,2)==="--")c=(getComputedStyle(e).getPropertyValue(g)+"").trim(),u+="",gr.lastIndex=0,gr.test(c)||(p=fn(c),m=fn(u)),m?p!==m&&(c=Sr(e,g,c,m)+m):p&&(u+=p),this.add(a,"setProperty",c,u,r,s,0,0,g),o.push(g),P.push(g,0,a[g]);else if(d!=="undefined"){if(l&&g in l?(c=typeof l[g]=="function"?l[g].call(i,r,e,s):l[g],rn(c)&&~c.indexOf("random(")&&(c=ia(c)),fn(c+"")||c==="auto"||(c+=Vn.units[g]||fn(Fi(e,g))||""),(c+"").charAt(1)==="="&&(c=Fi(e,g))):c=Fi(e,g),f=parseFloat(c),x=d==="string"&&u.charAt(1)==="="&&u.substr(0,2),x&&(u=u.substr(2)),h=parseFloat(u),g in xi&&(g==="autoAlpha"&&(f===1&&Fi(e,"visibility")==="hidden"&&h&&(f=0),P.push("visibility",0,a.visibility),hr(this,a,"visibility",f?"inherit":"hidden",h?"inherit":"hidden",!h)),g!=="scale"&&g!=="transform"&&(g=xi[g],~g.indexOf(",")&&(g=g.split(",")[0]))),_=g in Vi,_){if(this.styles.save(g),y||(C=e._gsap,C.renderTransform&&!t.parseTransform||aa(e,t.parseTransform),M=t.smoothOrigin!==!1&&C.smooth,y=this._pt=new Pn(this._pt,a,Ot,0,1,C.renderTransform,C,0,-1),y.dep=1),g==="scale")this._pt=new Pn(this._pt,C,"scaleY",C.scaleY,(x?Ys(C.scaleY,x+h):h)-C.scaleY||0,mh),this._pt.u=0,o.push("scaleY",g),g+="X";else if(g==="transformOrigin"){P.push(Ln,0,a[Ln]),u=WS(u),C.svg?_h(e,u,0,M,0,this):(m=parseFloat(u.split(" ")[2])||0,m!==C.zOrigin&&hr(this,C,"zOrigin",C.zOrigin,m),hr(this,a,g,Dl(c),Dl(u)));continue}else if(g==="svgOrigin"){_h(e,u,1,M,0,this);continue}else if(g in lm){YS(this,C,g,f,x?Ys(f,x+u):u);continue}else if(g==="smoothOrigin"){hr(this,C,"smooth",C.smooth,u);continue}else if(g==="force3D"){C[g]=u;continue}else if(g==="transform"){KS(this,u,e);continue}}else g in a||(g=ao(g)||g);if(_||(h||h===0)&&(f||f===0)&&!PS.test(u)&&g in a)p=(c+"").substr((f+"").length),h||(h=0),m=fn(u)||(g in Vn.units?Vn.units[g]:p),p!==m&&(f=Sr(e,g,c,m)),this._pt=new Pn(this._pt,_?C:a,g,f,(x?Ys(f,x+h):h)-f,!_&&(m==="px"||g==="zIndex")&&t.autoRound!==!1?IS:mh),this._pt.u=m||0,p!==m&&m!=="%"&&(this._pt.b=c,this._pt.r=DS);else if(g in a)VS.call(this,e,g,c,x?x+u:u);else if(g in e)this.add(e,g,c||e[g],x?x+u:u,r,s);else if(g!=="parseTransform"){jh(g,u);continue}_||(g in a?P.push(g,0,a[g]):P.push(g,1,c||e[g])),o.push(g)}}w&&Qp(this)},render:function(e,t){if(t.tween._time||!af())for(var i=t._pt;i;)i.r(e,i.d),i=i._next;else t.styles.revert()},get:Fi,aliases:xi,getSetter:function(e,t,i){var r=xi[t];return r&&r.indexOf(",")<0&&(t=r),t in Vi&&t!==Ln&&(e._gsap.x||Fi(e,"x"))?i&&Od===i?t==="scale"?OS:FS:(Od=i||{})&&(t==="scale"?kS:BS):e.style&&!$h(e.style[t])?US:~t.indexOf("-")?NS:rf(e,t)},core:{_removeProperty:ns,_getMatrix:cf}};Ht.utils.checkPrefix=ao;Ht.core.getStyleSaver=rm;(function(n,e,t,i){var r=Rn(n+","+e+","+t,function(s){Vi[s]=1});Rn(e,function(s){Vn.units[s]="deg",lm[s]=1}),xi[r[13]]=n+","+e,Rn(i,function(s){var o=s.split(":");xi[o[1]]=r[o[0]]})})("x,y,z,scale,scaleX,scaleY,xPercent,yPercent","rotation,rotationX,rotationY,skewX,skewY","transform,transformOrigin,svgOrigin,force3D,smoothOrigin,transformPerspective","0:translateX,1:translateY,2:translateZ,8:rotate,8:rotationZ,8:rotateZ,9:rotateX,10:rotateY");Rn("x,y,z,top,right,bottom,left,width,height,fontSize,padding,margin,perspective",function(n){Vn.units[n]="px"});Ht.registerPlugin(hm);var Fn=Ht.registerPlugin(hm)||Ht;Fn.core.Tween;const jS="http://www.w3.org/2000/svg";function fm(n,e){for(const[t,i]of Object.entries(e||{}))i==null||i===!1||(t==="class"?n.setAttribute("class",i):t==="text"?n.textContent=i:t==="html"?n.innerHTML=i:t.startsWith("on")&&typeof i=="function"?n.addEventListener(t.slice(2),i):n.setAttribute(t,i===!0?"":String(i)));return n}function dm(n,e){for(const t of e.flat())t==null||t===!1||n.appendChild(typeof t=="string"?document.createTextNode(t):t);return n}function Xr(n,e,...t){return dm(fm(document.createElement(n),e),t)}function bn(n,e,...t){return dm(fm(document.createElementNS(jS,n),e),t)}const Yn=(n,e,t)=>Math.min(t,Math.max(e,n)),ZS=(n,e,t)=>n+(e-n)*t,or=n=>String(n).padStart(2,"0");function JS(){try{return window.matchMedia("(prefers-reduced-motion: reduce)").matches}catch{return!1}}const QS='a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"]), input, select, textarea';function eM(n){return[...n.querySelectorAll(QS)].filter(e=>{if(e.closest("[inert]"))return!1;const t=e.getBoundingClientRect();return t.width>0||t.height>0})}function tM(n,e){if(e.key!=="Tab")return;const t=eM(n);if(!t.length){e.preventDefault();return}const i=t[0],r=t[t.length-1],s=document.activeElement;e.shiftKey&&(s===i||!n.contains(s))?(e.preventDefault(),r.focus()):!e.shiftKey&&(s===r||!n.contains(s))&&(e.preventDefault(),i.focus())}function nM(n){return!!n&&(n.isContentEditable||/^(INPUT|TEXTAREA|SELECT)$/.test(n.tagName))}function Xd(n){return new Promise(e=>setTimeout(e,n))}function iM(n){const e=/^(\d{1,2}):(\d{2})/.exec(String(n||"").trim());return e?Number(e[1])*60+Number(e[2]):NaN}function rM(n){const e=(Math.round(n)%1440+1440)%1440;return`${or(Math.floor(e/60))}:${or(e%60)}`}const Il={monitor:'<rect x="3" y="4.25" width="18" height="12.5" rx="2"/><path d="M6 11h2.4l1.5-3.2 2.3 6.4 1.8-5 1.1 1.8H18"/><path d="M12 16.75v3M8.25 19.75h7.5"/>',dental:'<path d="M12 5.6C10.6 4.4 9.4 3.8 8 3.8 5.5 3.8 4 5.7 4 8.3c0 2.1.8 3.7 1.4 5.5.6 1.8.8 3.8 1.3 5.6.3 1 .8 1.4 1.4 1.4.7 0 1.1-.6 1.4-1.8l.7-2.8c.2-.9.8-1.4 1.8-1.4s1.6.5 1.8 1.4l.7 2.8c.3 1.2.7 1.8 1.4 1.8.6 0 1.1-.4 1.4-1.4.5-1.8.7-3.8 1.3-5.6.6-1.8 1.4-3.4 1.4-5.5 0-2.6-1.5-4.5-4-4.5-1.4 0-2.6.6-4 1.8z"/>',slitlamp:'<path d="M2.75 15.5c2.2-3.3 5.4-5 9.25-5s7.05 1.7 9.25 5c-2.2 3.3-5.4 5-9.25 5s-7.05-1.7-9.25-5z"/><circle cx="12" cy="15.5" r="2.4"/><path d="M14.6 2.75h4.6M15.6 2.75l-3.3 9.9M18.2 2.75l-5.3 9.9"/>',microscope:'<path d="M7.3 3.3l3-1.1 3.3 8.6-3 1.1z"/><path d="M10.9 11.6l.7 1.9M8 15.5h7.5M4.5 20.5h15"/><path d="M14.6 6.6c2.9.9 4.9 3.6 4.9 6.7 0 3-1.8 5.6-4.4 6.7"/>',centrifuge:'<circle cx="12" cy="12" r="8.75"/><circle cx="12" cy="7.1" r="2"/><circle cx="16.25" cy="14.45" r="2"/><circle cx="7.75" cy="14.45" r="2"/><path d="M12 12h.01"/>',autoclave:'<rect x="2.75" y="9.75" width="18.5" height="11.25" rx="2"/><circle cx="10" cy="15.4" r="3.9"/><circle cx="10" cy="15.4" r="2.1"/><circle cx="17.6" cy="13.1" r="1.1"/><path d="M16.4 17.9h2.4"/><path d="M7.6 2.5c-.9.9-.9 1.8 0 2.7s.9 1.8 0 2.7M11.4 2.5c-.9.9-.9 1.8 0 2.7s.9 1.8 0 2.7"/>'},qd={ecg:"monitor",heartbeat:"monitor",pulse:"monitor",vitals:"monitor","patient-monitor":"monitor",tooth:"dental",molar:"dental","dental-chair":"dental",chair:"dental",eye:"slitlamp","slit-lamp":"slitlamp",slit:"slitlamp",scope:"microscope","lab-microscope":"microscope",rotor:"centrifuge",spin:"centrifuge","spinning-rotor":"centrifuge","lab-centrifuge":"centrifuge",steam:"autoclave","steam-drop":"autoclave",sterilizer:"autoclave",steriliser:"autoclave",cssd:"autoclave"},ko=["monitor","dental","slitlamp","microscope","centrifuge","autoclave"],sM=n=>String(n??"").toLowerCase().trim().replace(/[\s_]+/g,"-");function xh(n){const e=sM(n);if(!e)return"";if(Il[e])return e;if(qd[e])return qd[e];const t=e.replace(/-/g,"");return Il[t]?t:""}function oM(n,e=0){return xh(n?.id)||xh(typeof n?.glyph=="string"&&n.glyph.length<40?n.glyph:"")||ko[(e%ko.length+ko.length)%ko.length]}const pm=n=>`<svg class="${n}" viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">`;function $d(n,e="esu-glyph"){return`${pm(e)}${Il[n]||Il[ko[0]]}</svg>`}const aM=/^[MmLlHhVvCcSsQqTtAaZz0-9eE\s.,+-]+$/,lM=n=>typeof n=="string"&&/^\s*[Mm]/.test(n)&&aM.test(n)&&n.length<4e3;function qc(n,e,t="esu-glyph"){const i=xh(n?.id);return i?$d(i,t):lM(n?.glyph)?`${pm(t)}<path d="${n.glyph.trim()}"/></svg>`:$d(oM(n,e),t)}const cM="M126.581 97.3678C124.852 97.5386 122.856 97.8455 122.144 98.05C117.013 99.5229 115.506 100.055 113.504 101.1C104.842 105.624 99.6661 113.262 97.3564 124.928C96.871 127.382 97.0471 196.459 97.5398 196.951C97.762 197.174 133.974 197.153 134.197 196.93C134.253 196.875 134.407 184.868 134.538 170.25C134.81 140.121 134.747 140.813 137.473 138.165C140.805 134.933 135.668 135.192 198.87 135.064C238.771 134.983 255.285 135.068 256.739 135.361C262.67 136.558 265.543 140.35 265.6 147.056C265.625 150.025 268.115 149.763 239.913 149.763C212.917 149.763 208.93 149.953 203.862 151.476C192.257 154.965 185.953 161.648 182.314 174.318C181.653 176.617 181.545 178.435 181.334 190.75C180.957 212.732 181.572 212.166 158.042 212.167C150.398 212.167 133.537 212.278 120.572 212.412L97 212.657V242.968C97.001 275.675 96.96 274.909 99.0147 281.326C102.147 291.11 109.1 298.104 118.388 300.812C119.742 301.207 121.349 301.688 121.959 301.881C125.163 302.894 132.844 303.003 200.296 303C266.972 302.997 274.305 302.895 277.815 301.916C292.104 297.932 298.451 291.593 302.045 277.719L303 274.036L302.922 238.578C302.879 219.077 302.719 203.037 302.568 202.935C302.415 202.834 294.038 202.795 283.952 202.85L265.613 202.949L265.6 228.882C265.584 259.729 265.599 259.604 261.605 262.647C258.646 264.9 261.951 264.785 200.164 264.785C145.298 264.785 143.334 264.761 141.253 264.08C136.731 262.599 134.716 259.268 134.716 253.272V250.2H160.43C189.049 250.2 191.376 250.068 197.206 248.128C205.863 245.247 211.758 240.188 215.074 232.792C218.262 225.684 218.316 225.326 218.627 209.212C218.921 193.972 218.955 193.749 221.454 190.783C224.011 187.749 222.859 187.802 293.622 187.47L302.959 187.427V156.624C302.959 123.125 303.072 125.177 300.841 118.216C297.835 108.84 290.747 101.826 281.571 99.1506C280.217 98.7558 278.61 98.273 278 98.0787C274.854 97.0743 266.609 96.9617 199.239 97.0088C161.006 97.0364 128.31 97.198 126.581 97.3678Z";function $c(n="esu-logo"){return`<svg class="${n}" viewBox="97 97 206 206" aria-hidden="true" focusable="false" fill="currentColor"><path d="${cM}"/></svg>`}function hi(n){const e='viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"';switch(n){case"close":return`<svg class="esu-ico" ${e}><path d="M6 6l12 12M18 6L6 18"/></svg>`;case"arrow":return`<svg class="esu-ico" ${e}><path d="M4 12h15M14 7l5 5-5 5"/></svg>`;default:return""}}const Yd="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&+=/<>*",Ko=new Set,lo=new WeakMap;let Ul=0;const Kd=()=>Yd[Math.random()*Yd.length|0];function mm(n){Ul=0;for(const e of[...Ko])e.step(n);Ko.size&&(Ul=requestAnimationFrame(mm))}function uM(){Ul||(Ul=requestAnimationFrame(mm))}function rr(n,e){gm(n),e=String(e??""),n.textContent="",n.dataset.text=e;const t=Xr("span",{class:"esu-dc","aria-hidden":"true"}),i=[];return e.split(`
`).forEach((s,o)=>{o&&t.appendChild(document.createElement("br")),s.split(/(\s+)/).forEach(a=>{if(!a)return;if(/^\s+$/.test(a)){t.appendChild(document.createTextNode(" "));return}const l=Xr("span",{class:"esu-w"});for(const c of a){const u=Xr("span",{class:"esu-c"},c);l.appendChild(u),i.push({el:u,ch:c,st:0})}t.appendChild(l)})}),n.append(Xr("span",{class:"esu-sr"},e),t),n._chars=i,i}function gm(n){const e=lo.get(n);e&&e.finish(!0)}function Gs(n,e){n.st!==e&&(n.st=e,n.el.classList.toggle("is-h",e===1),n.el.classList.toggle("is-s",e===2))}function uf(n,e,{cadence:t=48,outro:i=!1}={}){gm(n);let r=0,s=0,o;const a=new Promise(u=>{o=u}),l=Math.max(0,...e.map(u=>u.end)),c={outro:i,done:a,step(u){r||(r=u,s=u-t);const h=(u-r)/1e3,f=u-s>=t;f&&(s=u);for(const d of e)h<d.start?Gs(d,d.hideBefore?1:0):h<d.end?(Gs(d,2),f&&(d.el.dataset.g=d.outro&&Math.random()<.35?"":Kd())):Gs(d,d.outro?1:0);h>=l&&c.finish(!1)},finish(u){if(Ko.has(c)){if(Ko.delete(c),lo.delete(n),u)for(const h of e)Gs(h,h.outro?1:0);o(!u)}}};return Ko.add(c),lo.set(n,c),uM(),a}function Ni(n,e,{duration:t=.8,delay:i=0,scramble:r=.32,reduced:s=!1,random:o=.18}={}){const a=rr(n,e);if(s||!a.length)return n.classList.remove("esu-fade-in"),n.offsetWidth,n.classList.add("esu-fade-in"),Promise.resolve(!0);const l=a.length;return a.forEach((c,u)=>{const h=l>1?u/(l-1):0;c.start=i+h*t*(1-o)+Math.random()*t*o,c.end=c.start+r*(.55+Math.random()*.9),c.hideBefore=!0,Gs(c,1)}),uf(n,a)}function Ns(n,{duration:e=.28,reduced:t=!1}={}){const i=n._chars;if(!i?.length||t)return i&&i.forEach(s=>Gs(s,1)),Promise.resolve(!0);const r=i.length;return i.forEach((s,o)=>{const a=r>1?o/(r-1):0;s.start=a*e*.5*Math.random(),s.end=s.start+e*(.35+Math.random()*.65),s.hideBefore=!1,s.outro=!0}),uf(n,i,{cadence:40,outro:!0})}function fi(n,e,t={}){e=String(e??"");const i=n._swapToken=(n._swapToken||0)+1;if(n.dataset.text===e&&!t.force){const a=lo.get(n);return a?.outro?Ni(n,e,t):a?a.done:Promise.resolve(!0)}const r=()=>i===n._swapToken?Ni(n,e,t):Promise.resolve(!1);if(!n._chars?.length||t.reduced)return r();const s=lo.get(n);return(s?.outro?s.done:Ns(n,{duration:t.outDuration??.24})).then(r)}function Qi(n,{duration:e=.42,reduced:t=!1}={}){const i=n._chars;if(!i?.length||t||lo.get(n))return Promise.resolve(!0);const r=i.length;return i.forEach((s,o)=>{const a=r>1?o/(r-1):0;s.start=0,s.end=.06+a*e+Math.random()*.08,s.hideBefore=!1,s.outro=!1}),uf(n,i,{cadence:42})}const yh='"Space Grotesk"',hf=500,la=200,hM={E:[["A",.5,.27,.42,.225,90,335],["A",.5,.73,.42,.225,25,270],["L",.5,.5,.84,.5]],Q:[["A",.5,.5,.44,.46,292,608],["D",.5,.5,.62],["L",.64,.7,.98,1.06]],U:[["L",.1,0,.1,.54],["L",.9,0,.9,.54],["A",.5,.54,.4,.42,0,180],["D",.5,.2,.62]],I:[["L",.08,.06,.92,.06],["L",.08,.94,.92,.94],["L",.5,.22,.5,.78]],P:[["L",.12,0,.12,.56],["L",.12,.7,.12,1],["A",.6,.29,.32,.27,212,508]],S:[["A",.5,.27,.38,.225,90,338],["A",.5,.73,.38,.225,270,518]],V:[["Q",.04,0,.5,1.88,.96,0],["D",.5,.26,.62]],A:[["L",.1,1,.1,.47],["L",.9,1,.9,.47],["A",.5,.47,.4,.47,180,360],["D",.5,.64,.62]],O:[["A",.5,.5,.44,.46,292,608],["D",.5,.5,.62]],N:[["L",.1,1,.1,.45],["A",.5,.45,.4,.45,180,360],["L",.9,.45,.9,1]],R:[["L",.12,0,.12,1],["A",.5,.28,.36,.26,270,450],["L",.5,.55,.92,1]]},jd="EQUIPSVA0123456789#%/<>=+";function fM(n,e,t,i,r,s){const o=(l,c)=>`${(e+l*i).toFixed(2)} ${(t+c*r).toFixed(2)}`;let a="";for(const l of n)if(l[0]==="L")a+=`M${o(l[1],l[2])}L${o(l[3],l[4])}`;else if(l[0]==="Q")a+=`M${o(l[1],l[2])}Q${o(l[3],l[4])} ${o(l[5],l[6])}`;else if(l[0]==="A"){const[,c,u,h,f,d,v]=l,g=m=>o(c+h*Math.cos(m*Math.PI/180),u+f*Math.sin(m*Math.PI/180)),p=v-d;p>=359.9?a+=`M${g(d)}A${(h*i).toFixed(2)} ${(f*r).toFixed(2)} 0 1 1 ${g(d+180)}A${(h*i).toFixed(2)} ${(f*r).toFixed(2)} 0 1 1 ${g(d)}`:a+=`M${g(d)}A${(h*i).toFixed(2)} ${(f*r).toFixed(2)} 0 ${p>180?1:0} 1 ${g(v)}`}else if(l[0]==="D"){const c=l[3]*s,[u,h]=o(l[1],l[2]).split(" ").map(Number);a+=`M${(u-c).toFixed(2)} ${h.toFixed(2)}a${c.toFixed(2)} ${c.toFixed(2)} 0 1 0 ${(2*c).toFixed(2)} 0a${c.toFixed(2)} ${c.toFixed(2)} 0 1 0 ${(-2*c).toFixed(2)} 0`}return a}function dM(n){let e=n.charCodeAt(0)*9301+49297;const t=()=>(e=(e*9301+49297)%233280)/233280;return[["L",.1,t()*.3,.9,t()*.3],["L",.1+t()*.3,.5,.9,.5],["L",.5,.2+t()*.3,.5,1]]}function pM(n){const e=document.createElement("canvas").getContext("2d");e.font=`${hf} ${la}px ${yh}, ui-sans-serif, system-ui, sans-serif`;const i=e.measureText("H").actualBoundingBoxAscent||la*.7,r=[];for(let s=0;s<n.length;s++){const o=n[s],a=e.measureText(n.slice(0,s)).width,l=e.measureText(o);r.push({ch:o,x:a,adv:l.width,inkL:a-(l.actualBoundingBoxLeft||0),inkR:a+(l.actualBoundingBoxRight||l.width)})}return{capH:i,letters:r,width:e.measureText(n).width}}function mM(n="EQUIPSEVA",{reduced:e=!1,track:t=-.012,lines:i=null,pitch:r=1.3}={}){const s=G=>String(G??"").toUpperCase().replace(/\s+/g,"");let o=(Array.isArray(i)?i:[]).map(s).filter(Boolean);o.length||(o=[s(n)||"EQUIPSEVA"]);const a=t*la,l=o.map(G=>{const he=pM(G);return he.letters.forEach((me,fe)=>{me.x+=a*fe,me.inkL+=a*fe,me.inkR+=a*fe}),he}),c=l[0].capH,u=c*.118,h=c*r,f=[];l.forEach((G,he)=>{const me=Math.min(...G.letters.map(se=>se.inkL)),fe=Math.max(...G.letters.map(se=>se.inkR)),De=-(me+fe)/2;G.letters.forEach(se=>f.push({...se,x:se.x+De,inkL:se.inkL+De,inkR:se.inkR+De,row:he,base:he*h}))});const d=c*.12,v=c*.14,g=Math.min(...f.map(G=>G.inkL))-d,p=Math.max(...f.map(G=>G.inkR))+d,m=(o.length-1)*h,x=[g,-c-v,p-g,c+m+v*2],_=Math.random().toString(36).slice(2,7),y=bn("svg",{class:"esu-wm",viewBox:x.map(G=>G.toFixed(2)).join(" "),"aria-hidden":"true",focusable:"false",style:`--wm-aspect:${(x[2]/x[3]).toFixed(4)}`}),C=bn("defs"),M=o.map((G,he)=>{const me=he*h,fe=me-c,De=fe+c*.52,se={t:`esu-wm-t${he}-${_}`,b:`esu-wm-b${he}-${_}`};return C.append(bn("clipPath",{id:se.t,clipPathUnits:"userSpaceOnUse"},bn("rect",{x:x[0]-400,y:fe-c,width:x[2]+800,height:De-fe+c})),bn("clipPath",{id:se.b,clipPathUnits:"userSpaceOnUse"},bn("rect",{x:x[0]-400,y:De,width:x[2]+800,height:me-De+c}))),se}),w=bn("g",{class:"esu-wm-alt",fill:"none",stroke:"currentColor","stroke-width":u.toFixed(2),"stroke-linecap":"butt"}),P=bn("g",{class:"esu-wm-txt"});y.append(C,P,w);const I={"font-size":la,"font-weight":hf},S=f.map(G=>{const he=V=>bn("text",{class:V,x:G.x.toFixed(2),y:G.base.toFixed(2),...I},G.ch),me=he("wm-f"),fe=he("wm-s"),De=he("wm-s"),se=bn("text",{class:"wm-r",x:(G.x+G.adv/2).toFixed(2),y:G.base.toFixed(2),"text-anchor":"middle",...I},"#"),U=G.inkR-G.inkL,Se=Math.max(U,c*.52),ye=G.inkL+(U-Se)/2,ge=bn("path",{class:"wm-a",d:fM(hM[G.ch]||dM(G.ch),ye,G.base-c,Se,c,u)}),B=bn("g",{class:"wm-l"},me,bn("g",{"clip-path":`url(#${M[G.row].t})`},fe),bn("g",{"clip-path":`url(#${M[G.row].b})`},De),se);return P.appendChild(B),w.appendChild(ge),{ch:G.ch,fin:me,sT:fe,sB:De,rnd:se,alt:ge,cache:new Map,mode:"hidden",ghost:0}}),b=(G,he,me,fe)=>{const se=(he===G.fin?"f":he===G.sT?"t":he===G.sB?"b":he===G.rnd?"r":"a")+me;G.cache.get(se)!==fe&&(G.cache.set(se,fe),me==="o"?he.style.opacity=fe:me==="x"?he.setAttribute("transform",fe):me==="c"?he.textContent=fe:me==="cl"&&he.setAttribute("class",fe))},N=c,R=G=>((Math.random()*2-1)*G*N).toFixed(1),H=()=>{const G=Math.random()*Math.PI*2,he=(.018+Math.random()*.016)*N;return`translate(${(Math.cos(G)*he).toFixed(1)} ${(Math.sin(G)*he*.6).toFixed(1)})`};function T(G,he){switch(G.mode=he,(()=>{b(G,G.fin,"o",0),b(G,G.sT,"o",0),b(G,G.sB,"o",0),b(G,G.rnd,"o",0),b(G,G.alt,"o",0)})(),he){case"final":b(G,G.fin,"o",1);break;case"final+alt":b(G,G.fin,"o",1),b(G,G.alt,"o",.9),b(G,G.alt,"x",H());break;case"slice":{const fe=Math.random()<.5,De=G.soft?.05:.1;b(G,G.sT,"o",1),b(G,G.sB,"o",1),b(G,G.sT,"x",`translate(${R(De)} 0)`),b(G,G.sB,"x",`translate(${R(De)} 0)`),b(G,G.sT,"cl",fe?"wm-s is-mint":"wm-s"),b(G,G.sB,"cl",fe?"wm-s":"wm-s is-mint");break}case"alt":b(G,G.alt,"o",1),b(G,G.alt,"x",`translate(${R(.05)} ${R(.04)})`);break;case"rand":b(G,G.rnd,"o",.85),b(G,G.rnd,"c",jd[Math.random()*jd.length|0]),b(G,G.rnd,"x",`translate(${R(.06)} ${R(.03)})`);break}}function k(G){const he=Math.random();if(G.soft){he<.78?T(G,"final+alt"):T(G,"slice");return}he<.42?T(G,"final+alt"):he<.64?T(G,"slice"):he<.76?T(G,"alt"):he<.88?T(G,"rand"):T(G,"hidden")}let Z=0,K=!1,pe=0,ce=0,W=!1,re=0;const Ae=56;function ee(G){if(Z=0,!K)return;const he=G-pe>=Ae;he&&(pe=G);let me=!1;for(const fe of S){if(fe.end&&G<fe.start){fe.mode!=="hidden"&&!fe.keepFinal&&T(fe,"hidden"),me=!0;continue}if(fe.end&&G<fe.end){he&&k(fe),me=!0;continue}if(fe.end){if(fe.end=0,fe.exiting){T(fe,"hidden"),fe.gone=!0;continue}T(fe,"final"),fe.ghost=G,b(fe,fe.alt,"x","translate(0 0)")}if(fe.ghost){const De=1-(G-fe.ghost)/320;De<=0?(fe.ghost=0,b(fe,fe.alt,"o",0)):(b(fe,fe.alt,"o",(.75*De).toFixed(3)),me=!0)}}if(W&&!re&&G>=ce){const fe=Math.random()*S.length|0,De=Math.random()<.35?[fe,Math.min(S.length-1,fe+1)]:[fe];for(const se of De){const U=S[se];U.end||(U.start=G,U.end=G+180+Math.random()*320,U.keepFinal=!0,U.soft=!0)}ce=G+260+Math.random()*900}me||W?Z=requestAnimationFrame(ee):K=!1}function F(){K||(K=!0,Z=requestAnimationFrame(ee))}const xe=Xr("div",{class:"esu-wm-wrap"},y);return S.forEach(G=>T(G,e?"final":"hidden")),{el:xe,assemble({spread:G=1.15,min:he=.45,max:me=.95}={}){if(e)return S.forEach(U=>T(U,"final")),Promise.resolve();const fe=performance.now(),De=S.map((U,Se)=>Se).sort(()=>Math.random()-.5);let se=0;return De.forEach((U,Se)=>{const ye=S[U];ye.start=fe+Se/S.length*G*1e3*.7+Math.random()*G*300,ye.end=ye.start+(he+Math.random()*(me-he))*1e3,ye.keepFinal=!1,ye.soft=!1,se=Math.max(se,ye.end)}),F(),new Promise(U=>setTimeout(U,se-fe+340))},startIdle(){e||(W=!0,ce=performance.now()+900+Math.random()*900,F())},stopIdle(){W=!1},exit(){if(W=!1,e)return S.forEach(me=>T(me,"hidden")),Promise.resolve();const G=performance.now();re=G;let he=0;return S.forEach(me=>{me.start=G+Math.random()*120,me.end=me.start+90+Math.random()*260,me.exiting=!0,me.keepFinal=!0,me.ghost=0,me.soft=!1,he=Math.max(he,me.end)}),F(),new Promise(me=>setTimeout(me,he-G+40))},destroy(){K=!1,W=!1,Z&&cancelAnimationFrame(Z),xe.remove()}}}function Zd(n=2500){if(!document.fonts?.load)return Promise.resolve();const e=Promise.all([document.fonts.load(`${hf} ${la}px ${yh}`),document.fonts.load(`400 16px ${yh}`)]).catch(()=>{});return Promise.race([e,new Promise(t=>setTimeout(t,n))])}const Yc=[{id:"monitor",name:"Vitals monitor",department:"Wards",time:"05:40",label:"Dawn"},{id:"dental",name:"Dental chair",department:"Dental clinic",time:"09:00",label:"Morning"},{id:"slitlamp",name:"Slit lamp",department:"Eye OPD",time:"13:00",label:"Noon"},{id:"microscope",name:"Lab microscope",department:"Pathology lab",time:"17:30",label:"Dusk"},{id:"centrifuge",name:"Lab centrifuge",department:"24-hour lab",time:"21:00",label:"Night"},{id:"autoclave",name:"Autoclave",department:"CSSD",time:"02:00",label:"Deep night"}],Sh="mailto:support@equipseva.com",gM=[{label:"Contact",href:Sh,desc:"support@equipseva.com"}],vM=[{label:"Request service",href:`${Sh}?subject=${encodeURIComponent("Service request")}`},{label:"Join as an engineer",href:`${Sh}?subject=${encodeURIComponent("Engineer sign-up")}`}],_M=[{label:"Privacy",href:"https://equipseva.com/privacy/"},{label:"Terms",href:"https://equipseva.com/terms/"},{label:"Refunds",href:"https://equipseva.com/refunds/"}],xM="Hyderabad, Telangana",Kc={menu:"Menu",close:"Close",explore:"Explore",prev:"Prev",next:"Next",drag:"Drag through the day",story:"Story",timeline:"Timeline",sound:"Sound",on:"On",off:"Off",fixesTitle:"Common faults engineers fix",amcTitle:"What an AMC gives you",engineerTitle:"Your engineer",escHint:"to close"},Jd="Verified biomedical engineers for hospital equipment",Ye=(n,e="")=>typeof n=="string"&&n.trim()?n.trim():typeof n=="number"?String(n):e,Mh=n=>Array.isArray(n)?n.map(e=>typeof e=="string"?e:Ye(e?.label||e?.text||e?.title)).filter(Boolean):[];function sr(n){return(Array.isArray(n)?n:n&&typeof n=="object"?Object.values(n):[]).map(t=>t&&typeof t=="object"?{label:Ye(t.label||t.text||t.title),href:Ye(t.href||t.url,"#"),desc:Ye(t.desc||t.description),page:Ye(t.page)}:null).filter(t=>t&&t.label)}function yM(n){const e={};if(!n||typeof n!="object")return e;for(const[t,i]of Object.entries(n)){if(!i||typeof i!="object")continue;const r=(Array.isArray(i.sections)?i.sections:[]).map(s=>({title:Ye(s?.title),items:Mh(s?.items),text:Ye(s?.text)})).filter(s=>s.items.length||s.text);e[t]={id:Ye(i.id,t),label:Ye(i.label,t),kicker:Ye(i.kicker),headline:Ye(i.headline,Ye(i.label,t)),lead:Ye(i.lead),sections:r,specs:vm(i.specs),ctas:sr(i.ctas)}}return e}function vm(n){return Array.isArray(n)?n.map(e=>({k:Ye(e?.k??e?.key??e?.label),v:Ye(e?.v??e?.value)})).filter(e=>e.k&&e.v):[]}function SM(n,e){if(Array.isArray(n))return n.map(i=>Ye(i)).filter(Boolean);const t=Ye(n);return t?t.includes(`
`)?t.split(`
`).map(i=>i.trim()).filter(Boolean):t.includes(" / ")?t.split(" / ").map(i=>i.trim()).filter(Boolean):[t]:e}function MM(n={}){n=n||{};const t=(Array.isArray(n.steps)&&n.steps.length?n.steps:Yc).map((_,y)=>{const C=Yc[y]||Yc[0],M=Array.isArray(n.timeline)?n.timeline[y]||{}:{};return{id:Ye(_?.id,C.id),name:Ye(_?.name,C.name),title:Ye(_?.title,Ye(_?.name,C.name)),department:Ye(_?.department,C.department),time:Ye(M.time,Ye(_?.time,C.time)),timeLabel:Ye(M.label,Ye(_?.shift,Ye(_?.mood,C.label))),story:Ye(_?.story,Ye(_?.text,"")),glyph:_?.glyph}}),i=sr(n.ctas).length?sr(n.ctas):vM,r=t.map((_,y)=>{const C=Array.isArray(n.explore)&&n.explore[y]||{},M=sr(C.ctas);return{headline:Ye(C.headline,_.title),lead:Ye(C.lead,_.story),fixes:Mh(C.fixes),amc:Mh(C.amc),engineer:Ye(C.engineer),specs:vm(C.specs),ctas:M.length?M:i}});let s=-1/0;const o=t.map((_,y)=>{let C=iM(_.time);for(Number.isFinite(C)||(C=Number.isFinite(s)?s+180:330+y*180);C<s;)C+=1440;return s=C,C}),a=Ye(n.brand?.name,"EquipSeva"),l=a.split(/(?=[A-Z])/).filter(Boolean),c=Array.isArray(n.brand?.lockup)&&n.brand.lockup.length>=2?[Ye(n.brand.lockup[0]),Ye(n.brand.lockup[1])]:l.length>=2?[l[0],l.slice(1).join("")]:[a,""],u=SM(n.captionLines??n.hud?.caption??n.brand?.caption,["Verified engineers for","the machines that","keep care moving"]),h={...Kc};if(n.labels&&typeof n.labels=="object")for(const _ of Object.keys(Kc))h[_]=Ye(n.labels[_],Kc[_]);const f=_=>Ye(_).replace(/[^\d+]/g,""),d=Ye(n.contact?.phone),v=Ye(n.contact?.whatsapp),g={email:Ye(n.contact?.email),app:n.contact?.app&&Ye(n.contact.app.label)?{label:Ye(n.contact.app.label),href:Ye(n.contact.app.href,"#")}:null,phone:f(d).length>=8?{label:d,href:`tel:${f(d)}`}:null,whatsapp:f(v).length>=8?{label:"WhatsApp",href:`https://wa.me/${f(v).replace(/^\+/,"")}`}:null,location:Ye(n.contact?.location??n.contact?.address??n.contact?.city??n.brand?.location,xM)},p=sr(n.legal).length?sr(n.legal):_M,m=yM(n.pages),x=(sr(n.menu).length?sr(n.menu):gM).map(_=>({..._,page:_.page&&m[_.page]?_.page:""}));return{brand:{name:a,tagline:Ye(n.brand?.tagline,Jd),lockup:c},hudCaption:u,loader:{line1:Ye(n.loader?.line1,"Initialising Seva network"),line2:Ye(n.loader?.line2,"Loading, please wait")},intro:{wordmark:Ye(n.intro?.wordmark,a).toUpperCase(),cta:Ye(n.intro?.cta,"Click to enter"),caption:Ye(n.intro?.caption,""),descriptor:Ye(n.intro?.descriptor,Ye(n.brand?.tagline,Jd))},steps:t,minutes:o,explore:r,menu:x,ctas:i,menuFoot:Ye(n.menuFoot??n.brand?.footer,""),labels:h,contact:g,legal:p,pages:m}}const Oe=n=>String(n??"").replace(/[&<>"']/g,e=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[e]),_m="equipseva:sound";function bM(){try{return localStorage.getItem(_m)!=="off"}catch{return!0}}function wM(n){try{localStorage.setItem(_m,n?"on":"off")}catch{}}function jc(){return`<svg class="esu-orbits" viewBox="0 0 1000 1000" aria-hidden="true" focusable="false">${[[500,500,330],[500,500,470],[90,820,520],[930,140,480],[-60,260,430],[760,1080,400],[300,-120,560]].map(([e,t,i],r)=>`<circle cx="${e}" cy="${t}" r="${i}" style="--i:${r}"/>`).join("")}</svg>`}function EM(){const t=(s,o)=>[o*Math.cos(s*Math.PI/180),o*Math.sin(s*Math.PI/180)].map(a=>a.toFixed(2)).join(" ");let i="";for(let s=0;s<4;s++){const o=45+s*90+6.5,a=135+s*90-13/2;i+=`<path class="esu-dial-arc" pathLength="1" d="M${t(o,54)}A54 54 0 0 1 ${t(a,54)}"/>`}const r=[45,135,225,315].map(s=>`<circle class="esu-dial-dot" r="1.7" style="--a:${s}deg"/>`).join("");return`<svg class="esu-dial-svg" viewBox="-80 -80 160 160" aria-hidden="true" focusable="false">
    <g class="esu-dial-turn"><g class="esu-dial-spin">${i}${r}</g></g>
    <circle class="esu-dial-inner" r="38"/>
    <circle class="esu-dial-pulse" r="54"/>
  </svg>`}function TM({root:n,bus:e,content:t,loaded:i=!1}={}){if(!n)throw new Error("createUI: root element required");const r=MM(t);try{window.matchMedia("(pointer: coarse)").matches&&(r.intro.cta=r.intro.cta.replace(/^click\b/i,D=>D===D.toUpperCase()?"TAP":"Tap"))}catch{}const s=r.steps.length,o=JS(),a={phase:"loading",mode:"story",step:0,overlay:null,sound:bM(),loaded:!1,target:0,shown:0,tier:"high"},l=[];let c=!1,u=!1,h="";const f=(()=>{try{return window.history&&typeof window.history.pushState=="function"?window.history:null}catch{return null}})(),d=(D,J,be,je)=>{D.addEventListener(J,be,je),l.push(()=>D.removeEventListener(J,be,je))},v=(D,J)=>{e.on(D,J),l.push(()=>e.off(D,J))};let g=!1;const p=(D,J)=>{g=!0;try{e.emit(D,J)}finally{g=!1}},m=(D,J)=>p(D==="hover"?"ui:hover":"ui:click",{kind:J}),x=r.labels,_=Math.ceil(s/2),y=(D,J)=>`<button class="esu-gl" type="button" data-step="${J}" data-sfx="glyph" style="--i:${J}"
      aria-label="${Oe(D.name)} — ${Oe(D.department)}, ${Oe(D.time)}">
      <span class="esu-gl-ring" aria-hidden="true"></span>${qc(D,J)}
      <span class="esu-gl-tip" aria-hidden="true">${Oe(D.name)}<em>${Oe(D.time)}</em></span></button>`,C=r.steps.map((D,J)=>`<span class="esu-tl-tick" style="--i:${J}"><i></i><em>${Oe(D.time)}</em></span>`).join(""),M=r.hudCaption.map(D=>`<span>${Oe(D)}</span>`).join(" "),w=r.contact.email?`<a href="mailto:${Oe(r.contact.email)}" data-sfx="link">${Oe(r.contact.email)}</a>`:"",P=[r.contact.phone?`<a href="${Oe(r.contact.phone.href)}" data-sfx="link">${Oe(r.contact.phone.label)}</a>`:"",r.contact.whatsapp?`<a href="${Oe(r.contact.whatsapp.href)}" data-sfx="link" rel="noopener">${Oe(r.contact.whatsapp.label)}</a>`:""].filter(Boolean).join(""),I=[w,P,r.contact.app?`<a href="${Oe(r.contact.app.href)}" data-sfx="link" rel="noopener">${Oe(r.contact.app.label)}</a>`:""].filter(Boolean).join(""),S=r.legal.map(D=>`<a href="${Oe(D.href)}" data-sfx="link" rel="noopener">${Oe(D.label)}</a>`).join(""),b=r.ctas[0],N=Xr("div",{class:"esu","data-phase":"loading","data-mode":"story","data-overlay":"none","data-step":"0","data-page":"none"});o&&(N.dataset.reduced="1"),N.innerHTML=`
  <h1 class="esu-sr">${Oe(r.brand.name)} — ${Oe(r.brand.tagline)}</h1>
  <div class="esu-scrim" aria-hidden="true"></div>

  <section class="esu-loader" aria-label="Loading">
    ${jc()}
    <div class="esu-loader-c">
      ${$c("esu-logo esu-loader-logo")}
      <p class="esu-loader-l1"></p>
      <p class="esu-loader-l2"></p>
      <div class="esu-loader-bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" aria-label="Loading"><i></i></div>
    </div>
    <span class="esu-loader-pc" aria-hidden="true">000</span>
  </section>

  <section class="esu-intro" role="button" tabindex="-1" aria-disabled="true" aria-label="${Oe(r.intro.cta)} — ${Oe(r.brand.name)}">
    ${jc()}
    <div class="esu-intro-c">
      <div class="esu-intro-wm"></div>
      <p class="esu-intro-desc" aria-hidden="true"></p>
      <p class="esu-intro-cta" aria-hidden="true"></p>
    </div>
    <p class="esu-intro-cap" aria-hidden="true"></p>
  </section>

  <div class="esu-hud" inert>
    ${b?`<a class="esu-req" href="${Oe(b.href)}" data-sfx="cta"><span>${Oe(b.label)}</span>${hi("arrow")}</a>`:""}
    <button class="esu-menubtn" type="button" data-sfx="menu" aria-expanded="false" aria-controls="esu-menu">
      <span class="esu-menubtn-l"></span><span class="esu-bars" aria-hidden="true"><i></i><i></i><i></i></span>
    </button>

    <div class="esu-stage">
      <div class="esu-stage-row">
        <button class="esu-nav esu-prev" type="button" data-sfx="prev" aria-label="Previous machine">
          <span class="esu-nav-line" aria-hidden="true"></span><span class="esu-nav-seg" aria-hidden="true"></span><span class="esu-nav-l">${Oe(x.prev)}</span>
        </button>
        <button class="esu-dial" type="button" data-sfx="explore" aria-label="${Oe(x.explore)}">
          ${EM()}
          <span class="esu-dial-glyph" aria-hidden="true"></span>
          <svg class="esu-dial-lead" viewBox="0 0 64 40" aria-hidden="true" focusable="false"><path d="M0.5 39.5L26 4.5H64"/></svg>
          <span class="esu-dial-label" aria-hidden="true"></span>
        </button>
        <button class="esu-nav esu-next" type="button" data-sfx="next" aria-label="Next machine">
          <span class="esu-nav-l">${Oe(x.next)}</span><span class="esu-nav-seg" aria-hidden="true"></span><span class="esu-nav-line" aria-hidden="true"></span>
        </button>
      </div>
      <div class="esu-story">
        <p class="esu-kicker"><span class="esu-k-idx"></span><span class="esu-k-txt"></span></p>
        <h2 class="esu-title" aria-live="polite"></h2>
        <p class="esu-text"></p>
      </div>
    </div>

    <div class="esu-tl">
      <h2 class="esu-tl-title"></h2>
      <div class="esu-tl-track" data-sfx="knob">
        <div class="esu-tl-line" aria-hidden="true"><i class="esu-tl-dots"></i><i class="esu-tl-solid"></i></div>
        <div class="esu-tl-ticks" aria-hidden="true">${C}</div>
        <div class="esu-tl-knob" role="slider" tabindex="0" aria-label="Service clock" aria-valuemin="1" aria-valuemax="${s}" aria-valuenow="1">
          <span class="esu-tl-drag" aria-hidden="true">${Oe(x.drag)}</span>
          <span class="esu-tl-dot" aria-hidden="true"><i></i></span>
          <span class="esu-tl-time" aria-hidden="true"></span>
          <span class="esu-tl-sub" aria-hidden="true"></span>
        </div>
      </div>
    </div>

    <footer class="esu-bar">
      <div class="esu-brand">
        ${$c("esu-logo esu-brand-logo")}
        <span class="esu-lockup"><span>${Oe(r.brand.lockup[0])}</span><span>${Oe(r.brand.lockup[1])}</span></span>
        <p class="esu-cap">${M}</p>
      </div>
      <nav class="esu-glyphs" aria-label="Machines">
        <div class="esu-gl-row">
          <div class="esu-gl-grp">${r.steps.slice(0,_).map((D,J)=>y(D,J)).join("")}</div>
          <div class="esu-gl-gap" aria-hidden="true"></div>
          <div class="esu-gl-grp">${r.steps.slice(_).map((D,J)=>y(D,J+_)).join("")}</div>
        </div>
      </nav>
      <button class="esu-mode" type="button" role="switch" aria-checked="false" data-sfx="mode" aria-label="${Oe(x.timeline)} mode">
        <span class="esu-mode-o is-story" aria-hidden="true">${Oe(x.story)}</span>
        <span class="esu-mode-track" aria-hidden="true"><i></i></span>
        <span class="esu-mode-o is-time" aria-hidden="true">${Oe(x.timeline)}</span>
      </button>
      <button class="esu-sound" type="button" data-sfx="sound" aria-pressed="true" aria-label="Sound">
        <span class="esu-sound-s" aria-hidden="true">${Oe(x.sound)}</span>
        <svg class="esu-sound-w" viewBox="0 0 32 8" aria-hidden="true" focusable="false"><path d=""/></svg>
        <span class="esu-sound-st" aria-hidden="true"></span>
      </button>
    </footer>
  </div>

  <section class="esu-explore" id="esu-explore" role="dialog" aria-modal="true" aria-labelledby="esu-ex-h" inert>
    <div class="esu-ex-scrim" aria-hidden="true"></div>
    <div class="esu-ex-meta">
      <span class="esu-ex-glyph" aria-hidden="true"></span>
      <span class="esu-ex-count"></span>
      <span class="esu-ex-name"></span>
    </div>
    <button class="esu-close esu-ex-close" type="button" data-sfx="close" aria-label="${Oe(x.close)}">
      <span class="esu-close-l">${Oe(x.close)}</span><span class="esu-close-x" aria-hidden="true">${hi("close")}</span>
    </button>
    <div class="esu-ex-body">
      <div class="esu-ex-left">
        <p class="esu-ex-kicker"></p>
        <h2 class="esu-ex-h" id="esu-ex-h"></h2>
        <p class="esu-ex-lead"></p>
        <div class="esu-ex-ctas"></div>
        <dl class="esu-ex-specs"></dl>
        <section class="esu-ex-sec esu-ex-eng"><h3>${Oe(x.engineerTitle)}</h3><p></p></section>
      </div>
      <div class="esu-ex-right">
        <section class="esu-ex-sec esu-ex-fix"><h3>${Oe(x.fixesTitle)}</h3><ol></ol></section>
        <section class="esu-ex-sec esu-ex-amc"><h3>${Oe(x.amcTitle)}</h3><ul></ul></section>
      </div>
    </div>
    <div class="esu-ex-foot">
      <button class="esu-ex-nav is-prev" type="button" data-sfx="prev"><span class="esu-ex-arr" aria-hidden="true">${hi("arrow")}</span><span class="esu-ex-nl"></span></button>
      <p class="esu-ex-hint" aria-hidden="true"><span>Esc</span>${Oe(x.escHint)}</p>
      <button class="esu-ex-nav is-next" type="button" data-sfx="next"><span class="esu-ex-nl"></span><span class="esu-ex-arr" aria-hidden="true">${hi("arrow")}</span></button>
    </div>
  </section>

  <section class="esu-menu" id="esu-menu" role="dialog" aria-modal="true" aria-label="${Oe(x.menu)}" inert>
    <div class="esu-menu-bg" aria-hidden="true">${jc()}</div>
    <div class="esu-menu-brand" aria-hidden="true">${$c("esu-logo")}<span>${Oe(r.brand.name)}</span></div>
    <button class="esu-close esu-menu-close" type="button" data-sfx="close" aria-label="${Oe(x.close)}">
      <span class="esu-close-l">${Oe(x.close)}</span><span class="esu-close-x" aria-hidden="true">${hi("close")}</span>
    </button>
    <div class="esu-menu-scroll">
    <nav class="esu-menu-nav" aria-label="Main">
      <ol>${r.menu.map((D,J)=>`<li style="--i:${J}"><a class="esu-menu-a" href="${Oe(D.href)}" data-sfx="link"${D.page?` data-page="${Oe(D.page)}" aria-controls="esu-page"`:""}>
        <span class="esu-menu-idx" aria-hidden="true">${or(J+1)}</span><span class="esu-menu-lbl"></span>
        <span class="esu-menu-arr" aria-hidden="true">${hi("arrow")}</span>
        ${D.desc?`<span class="esu-menu-desc">${Oe(D.desc)}</span>`:""}</a></li>`).join("")}</ol>
    </nav>
    <aside class="esu-menu-side">
      <p class="esu-menu-tag">${Oe(r.brand.tagline)}</p>
      <div class="esu-menu-ctas">${r.ctas.slice(0,2).map((D,J)=>`<a class="esu-btn${J?"":" is-primary"}" href="${Oe(D.href)}" data-sfx="cta"><span>${Oe(D.label)}</span>${hi("arrow")}</a>`).join("")}</div>
      ${w||P?`<p class="esu-menu-contact">${w}${P}</p>`:""}
    </aside>
    </div>
    <div class="esu-page" id="esu-page" role="region" aria-labelledby="esu-page-h" inert>
      <button class="esu-page-back" type="button" data-sfx="close"><span class="esu-ex-arr" aria-hidden="true">${hi("arrow")}</span><span>${Oe(x.menu)}</span></button>
      <div class="esu-page-body">
        <div class="esu-ex-left">
          <p class="esu-ex-kicker"></p>
          <h2 class="esu-ex-h" id="esu-page-h"></h2>
          <p class="esu-ex-lead"></p>
          <div class="esu-ex-ctas"></div>
          <dl class="esu-ex-specs"></dl>
        </div>
        <div class="esu-ex-right"></div>
      </div>
    </div>
    <footer class="esu-menu-foot">
      <span class="esu-menu-org">© ${new Date().getFullYear()} ${Oe(r.brand.name)}${r.contact.location?` · ${Oe(r.contact.location)}`:""}<i class="esu-menu-clock" aria-hidden="true"></i></span>
      ${I?`<span class="esu-menu-links">${I}</span>`:`<span class="esu-menu-note">${Oe(r.menuFoot||"Made for hospitals across India")}</span>`}
      ${S?`<span class="esu-menu-legal">${S}</span>`:""}
      <span class="esu-menu-esc" aria-hidden="true"><b>Esc</b> ${Oe(x.escHint)}</span>
    </footer>
  </section>`,n.appendChild(N);const R=D=>N.querySelector(D),H=D=>[...N.querySelectorAll(D)],T={loader:R(".esu-loader"),l1:R(".esu-loader-l1"),l2:R(".esu-loader-l2"),bar:R(".esu-loader-bar"),barFill:R(".esu-loader-bar i"),pc:R(".esu-loader-pc"),intro:R(".esu-intro"),wm:R(".esu-intro-wm"),cta:R(".esu-intro-cta"),cap:R(".esu-intro-cap"),desc:R(".esu-intro-desc"),hud:R(".esu-hud"),menuBtn:R(".esu-menubtn"),menuBtnL:R(".esu-menubtn-l"),stage:R(".esu-stage"),brand:R(".esu-brand"),kIdx:R(".esu-k-idx"),kTxt:R(".esu-k-txt"),title:R(".esu-title"),text:R(".esu-text"),dial:R(".esu-dial"),dialGlyph:R(".esu-dial-glyph"),dialLabel:R(".esu-dial-label"),dialTurn:R(".esu-dial-turn"),prev:R(".esu-prev"),next:R(".esu-next"),tl:R(".esu-tl"),tlTitle:R(".esu-tl-title"),tlTrack:R(".esu-tl-track"),tlSolid:R(".esu-tl-solid"),tlKnob:R(".esu-tl-knob"),tlTime:R(".esu-tl-time"),tlSub:R(".esu-tl-sub"),tlDrag:R(".esu-tl-drag"),tlTicks:H(".esu-tl-tick"),glyphs:H(".esu-gl"),glyphNav:R(".esu-glyphs"),mode:R(".esu-mode"),sound:R(".esu-sound"),soundSt:R(".esu-sound-st"),soundPath:R(".esu-sound-w path"),ex:R(".esu-explore"),exGlyph:R(".esu-ex-glyph"),exCount:R(".esu-ex-count"),exName:R(".esu-ex-name"),exKicker:R(".esu-explore .esu-ex-kicker"),exH:R(".esu-explore .esu-ex-h"),exLead:R(".esu-explore .esu-ex-lead"),exCtas:R(".esu-explore .esu-ex-ctas"),exSpecs:R(".esu-explore .esu-ex-specs"),exPrev:R(".esu-ex-nav.is-prev"),exNext:R(".esu-ex-nav.is-next"),navL:H(".esu-nav-l"),exFix:R(".esu-ex-fix"),exAmc:R(".esu-ex-amc"),exEng:R(".esu-ex-eng"),exClose:R(".esu-ex-close"),menu:R(".esu-menu"),menuClose:R(".esu-menu-close"),menuLinks:H(".esu-menu-a"),menuClock:R(".esu-menu-clock"),menuNav:R(".esu-menu-nav"),menuSide:R(".esu-menu-side"),menuScroll:R(".esu-menu-scroll"),menuFoot:R(".esu-menu-foot"),story:R(".esu-story"),page:R(".esu-page"),pageBack:R(".esu-page-back"),pageBody:R(".esu-page-body"),pageKicker:R(".esu-page .esu-ex-kicker"),pageH:R(".esu-page .esu-ex-h"),pageLead:R(".esu-page .esu-ex-lead"),pageCtas:R(".esu-page .esu-ex-ctas"),pageSpecs:R(".esu-page .esu-ex-specs"),pageRight:R(".esu-page .esu-ex-right")};T.menuLinks.forEach((D,J)=>rr(D.querySelector(".esu-menu-lbl"),r.menu[J].label)),rr(T.dialLabel,x.explore),rr(T.menuBtnL,x.menu),T.navL.forEach(D=>rr(D,D.textContent));function k(D){a.phase=D,N.dataset.phase=D,Z()}function Z(){const D=a.phase==="home";T.hud.inert=!D||!!a.overlay,T.ex.inert=a.overlay!=="explore",T.menu.inert=a.overlay!=="menu",T.intro.inert=a.phase!=="intro",T.loader.inert=a.phase!=="loading"}const K=performance.now(),pe=o?500:1500;Ni(T.l1,r.loader.line1,{duration:.7,delay:.15,reduced:o}),Ni(T.l2,r.loader.line2,{duration:.6,delay:.45,reduced:o});let ce=0;function W(){ce=0,a.loaded||(a.target=Math.max(a.target,.82*(1-Math.exp(-(performance.now()-K)/4200))));const D=a.loaded?.16:.07;a.shown+=(a.target-a.shown)*D,a.target-a.shown<.002&&(a.shown=a.target),T.barFill.style.transform=`scaleX(${a.shown.toFixed(4)})`;const J=Math.round(a.shown*100);if(T.pc.textContent=String(J).padStart(3,"0"),T.bar.setAttribute("aria-valuenow",String(J)),a.loaded&&a.shown>=.999&&performance.now()-K>=pe){xe();return}a.phase==="loading"&&(ce=requestAnimationFrame(W))}ce=requestAnimationFrame(W),v("load:progress",D=>{const J=typeof D=="number"?D:D?.p;Number.isFinite(J)&&(a.target=Math.max(a.target,Yn(J,0,1)))}),v("load:done",()=>re());function re(){a.loaded||(a.loaded=!0,a.target=1,a.phase==="loading"&&!ce&&(ce=requestAnimationFrame(W)))}let Ae=null,ee=!1;const F=(()=>{const D=be=>String(be??"").toUpperCase().replace(/\s+/g,""),J=r.brand.lockup.map(D).filter(Boolean);return J.length>1&&J.join("")===D(r.intro.wordmark)?J:null})();async function xe(){if(ee||(ee=!0,await Zd(),c||a.phase!=="loading")||(Ns(T.l1,{reduced:o}),Ns(T.l2,{reduced:o}),N.classList.add("is-loader-out"),await Xd(o?150:420),c||a.phase!=="loading"))return;Ae=mM(r.intro.wordmark,{reduced:o,lines:F}),T.wm.appendChild(Ae.el),k("intro"),T.intro.setAttribute("aria-disabled","false"),T.intro.tabIndex=0;const D=Ae.assemble();Xd(o?200:1050).then(()=>{a.phase==="intro"&&(r.intro.descriptor&&Ni(T.desc,r.intro.descriptor,{duration:.9,scramble:.26,reduced:o}),Ni(T.cta,r.intro.cta,{duration:.6,delay:r.intro.descriptor?.45:0,reduced:o}),r.intro.caption&&Ni(T.cap,r.intro.caption,{duration:.8,delay:.6,reduced:o}))}),await D,a.phase==="intro"&&Ae.startIdle()}const G=o?.4:3;let he=null;function me({viaKey:D=!1}={}){if(a.phase!=="intro")return;m("click","enter"),p("intro:enter"),a.sound||p("sound:toggle",{on:!1}),k("entering"),N.classList.add("is-entering"),T.intro.setAttribute("aria-disabled","true"),Ns(T.cta,{reduced:o}),Ns(T.desc,{reduced:o}),r.intro.caption&&Ns(T.cap,{reduced:o});const J=Ae?Ae.exit():Promise.resolve(),be=new Promise(je=>{he=Fn.delayedCall(G,je)});Promise.all([J,be]).then(()=>{he=null,!c&&(k("home"),q(),D&&requestAnimationFrame(()=>T.dial.focus({preventScroll:!0})),setTimeout(()=>{Ae?.destroy(),Ae=null},1600))})}d(T.intro,"click",D=>me({viaKey:D.detail===0})),d(T.intro,"pointerenter",D=>{D.pointerType==="mouse"&&a.phase==="intro"&&m("hover","enter")});const fe=r.minutes;function De(D){const J=r.steps[D];return[J.name,J.time].filter(Boolean).join(" · ")}function se(D,{first:J=!1,force:be=!1}={}){const je=r.steps[D];T.kIdx.textContent=or(D+1);const ht={reduced:o,force:be};fi(T.kTxt,De(D),{...ht,duration:.45,delay:J?.1:.05}),fi(T.title,je.title,{...ht,duration:.55,delay:J?.2:.1,scramble:.36}),fi(T.text,je.story,{...ht,duration:J?1.1:.95,delay:J?.35:.18,scramble:.26,random:.25,outDuration:.2})}let U=0;function Se(D,J){T.dialGlyph.innerHTML=qc(r.steps[D],D),T.dialGlyph.classList.remove("is-swap"),T.dialGlyph.offsetWidth,T.dialGlyph.classList.add("is-swap"),J&&(U+=90*Math.sign(J),T.dialTurn.style.transform=`rotate(${U}deg)`),T.dial.setAttribute("aria-label",`Explore ${r.steps[D].name}`)}function ye(D,J,{first:be=!1}={}){N.dataset.step=String(D),T.glyphs.forEach((je,ht)=>{const lt=ht===D;je.classList.toggle("is-active",lt),lt?je.setAttribute("aria-current","step"):je.removeAttribute("aria-current"),lt&&!be&&(je.classList.remove("is-ping"),je.offsetWidth,je.classList.add("is-ping"))}),ge(D,be),T.prev.disabled=D<=0,T.next.disabled=D>=s-1,se(D,{first:be}),Se(D,be?0:D-J),dt(D,{animate:!be}),a.overlay==="explore"&&qe(D)}function ge(D,J=!1){const be=T.glyphNav,je=T.glyphs[D];if(!be||!je||be.scrollWidth<=be.clientWidth+1)return;const ht=be.getBoundingClientRect(),lt=je.getBoundingClientRect(),Mt=12;let Wt=0;lt.left<ht.left+Mt?Wt=lt.left-ht.left-Mt:lt.right>ht.right-Mt&&(Wt=lt.right-ht.right+Mt),Math.abs(Wt)>1&&be.scrollBy({left:Wt,behavior:J||o?"auto":"smooth"})}function B(D,J="nav"){if(D=Yn(D|0,0,s-1),D===a.step)return!1;const be=a.step;return a.step=D,ye(D,be),p("step:change",{index:D,prev:be,source:J}),rt(),!0}v("step:change",D=>{if(g||!D||!Number.isFinite(D.index))return;const J=Yn(D.index|0,0,s-1);if(J===a.step)return;const be=a.step;a.step=J,ye(J,be),rt()});function q(){ye(a.step,a.step,{first:!0}),de(),ot(),Zd().then(()=>{c||ot()}),Pe(a.step/Math.max(1,s-1)),a.mode==="timeline"&&fi(T.tlTitle,r.steps[a.step].title,{reduced:o,force:!0}),o||(Qi(T.menuBtnL),setTimeout(()=>Qi(T.dialLabel),900)),Ce()}let V=1,A=0,E=0,z=0,$=!1,ne=0,te=0,ve=40,ue=null,Me=0,Re=null;function de(){V=T.tlTrack.getBoundingClientRect().width||window.innerWidth,A=E=Yn(V*.1,44,190);const be=T.menuBtn.getBoundingClientRect();ve=be.width?Yn(Math.round(window.innerWidth-be.right),12,64):40,T.tlTicks.forEach((je,ht)=>{je.style.transform=`translateX(${Ee(ht/Math.max(1,s-1)).toFixed(1)}px)`}),te=T.tlTitle.offsetWidth,Pe(z,{silent:!0})}const Ee=D=>A+D*(V-A-E),Ne=D=>Yn((D-A)/Math.max(1,V-A-E),0,1);function Ve(D){const J=D*(s-1),be=Yn(Math.floor(J),0,s-1),je=Math.min(s-1,be+1);return ZS(fe[be],fe[je],J-be)}function Pe(D,{silent:J=!1}={}){z=Yn(D,0,1);const be=Ee(z);T.tlKnob.style.transform=`translateX(${be.toFixed(1)}px)`,T.tlSolid.style.transform=`scaleX(${(be/V).toFixed(4)})`,T.tl.style.setProperty("--kx",`${(be/V*100).toFixed(2)}%`),T.tlTime.textContent=rM(Ve(z));const je=te/2,ht=Yn(be,je+ve,V-je-ve);T.tlTitle.style.transform=`translateX(${(ht-je).toFixed(1)}px)`,T.tlTicks.forEach((Mt,Wt)=>{const ui=Math.abs(Ee(Wt/Math.max(1,s-1))-be);Mt.style.setProperty("--near",Yn((ui-26)/50,0,1).toFixed(3))});const lt=Math.round(z*(s-1));lt!==ne&&(ne=lt,!J&&$&&(m("hover","tick"),fi(T.tlTitle,r.steps[lt].title,{reduced:o,duration:.4,outDuration:.14}).then(Xe),T.glyphs.forEach((Mt,Wt)=>Mt.classList.toggle("is-near",Wt===lt&&Wt!==a.step))),T.tlSub.textContent=r.steps[lt].timeLabel||r.steps[lt].department);for(const Mt of[T.tlSub,T.tlDrag,T.tlTime]){const Wt=Mt.offsetWidth/2,ui=Math.min(ve,16);Mt.style.translate=Wt?`${(Yn(be,Wt+ui,V-Wt-ui)-be).toFixed(1)}px 0`:""}}function Xe(){te=T.tlTitle.offsetWidth,Pe(z,{silent:!0})}function We(D){Re=D,Me||(Me=requestAnimationFrame(()=>{Me=0,p("timeline:scrub",{t:Re})}))}function dt(D,{animate:J=!0}={}){if(T.tlKnob.setAttribute("aria-valuenow",String(D+1)),T.tlKnob.setAttribute("aria-valuetext",`${r.steps[D].time} — ${r.steps[D].name}, ${r.steps[D].department}`),T.glyphs.forEach(lt=>lt.classList.remove("is-near")),$)return;const be=D/Math.max(1,s-1);ue?.kill();const je=()=>{ne=D,T.tlSub.textContent=r.steps[D].timeLabel||r.steps[D].department};if(a.mode==="timeline"?fi(T.tlTitle,r.steps[D].title,{reduced:o,duration:.45}).then(Xe):(rr(T.tlTitle,r.steps[D].title),Xe()),!J||o||a.mode!=="timeline"){Pe(be,{silent:!0}),je();return}const ht={t:z};ue=Fn.to(ht,{t:be,duration:.9,ease:"expo.inOut",onUpdate:()=>Pe(ht.t,{silent:!0}),onComplete:je})}let X=0;function ie(D){if(a.mode!=="timeline"||D.button>0)return;D.preventDefault(),$=!0,X=D.clientX,ue?.kill(),T.tlTrack.setPointerCapture?.(D.pointerId),T.tl.classList.add("is-drag"),m("click","knob");const J=T.tlTrack.getBoundingClientRect();D.target.closest(".esu-tl-knob")||(Pe(Ne(D.clientX-J.left)),We(z)),T.tlKnob.focus({preventScroll:!0})}function Q(D){if(!$)return;Math.abs(D.clientX-X)>3;const J=T.tlTrack.getBoundingClientRect();Pe(Ne(D.clientX-J.left)),We(z)}function le(){if(!$)return;$=!1,T.tl.classList.remove("is-drag");const D=Math.round(z*(s-1)),J=D/Math.max(1,s-1);T.glyphs.forEach(je=>je.classList.remove("is-near")),m("click","snap"),D!==a.step?B(D,"timeline"):fi(T.tlTitle,r.steps[D].title,{reduced:o,duration:.3}).then(Xe),ue?.kill();const be={t:z};ue=Fn.to(be,{t:J,duration:o?.15:.6,ease:"expo.out",onUpdate:()=>{Pe(be.t,{silent:!0}),We(be.t)}})}d(T.tlTrack,"pointerdown",ie),d(T.tlTrack,"pointermove",Q),d(T.tlTrack,"pointerup",le),d(T.tlTrack,"pointercancel",le),d(T.tlTrack,"lostpointercapture",le),d(T.tlKnob,"keydown",D=>{D.key==="Home"?(D.preventDefault(),D.stopPropagation(),B(0,"timeline")):D.key==="End"?(D.preventDefault(),D.stopPropagation(),B(s-1,"timeline")):(D.key==="ArrowUp"||D.key==="ArrowDown"||D.key==="PageUp"||D.key==="PageDown")&&(D.preventDefault(),D.stopPropagation(),B(a.step+(D.key==="ArrowUp"||D.key==="PageUp"?1:-1),"timeline"))});function Te(D){D!=="story"&&D!=="timeline"||D!==a.mode&&(a.mode=D,N.dataset.mode=D,T.mode.setAttribute("aria-checked",String(D==="timeline")),D==="timeline"?(de(),Pe(a.step/Math.max(1,s-1),{silent:!0}),ne=a.step,T.tlSub.textContent=r.steps[a.step].timeLabel||r.steps[a.step].department,fi(T.tlTitle,r.steps[a.step].title,{reduced:o,duration:.5,delay:.25,force:!0}).then(Xe)):se(a.step,{first:!0,force:!0}),p("mode:change",{mode:D}))}let _e=null;function qe(D){const J=r.steps[D],be=r.explore[D];T.exGlyph.innerHTML=qc(J,D),T.exCount.textContent=`${or(D+1)} / ${or(s)}`,T.exName.textContent=J.name,T.exKicker.textContent=[J.department,J.time].filter(Boolean).join(" · "),fi(T.exH,be.headline,{reduced:o,duration:.7,delay:.25,force:!0}),T.exLead.textContent=be.lead,T.exCtas.innerHTML=be.ctas.slice(0,2).map((lt,Mt)=>`<a class="esu-btn${Mt?"":" is-primary"}" href="${Oe(lt.href)}" data-sfx="cta"><span>${Oe(lt.label)}</span>${hi("arrow")}</a>`).join("");const je=(lt,Mt,Wt)=>{lt.hidden=!Mt.length,lt.querySelector(Wt).innerHTML=Mt.map((ui,Mf)=>`<li style="--k:${Mf}"><span class="esu-li-n" aria-hidden="true">${or(Mf+1)}</span><span>${Oe(ui)}</span></li>`).join("")};T.exSpecs.innerHTML=be.specs.slice(0,4).map((lt,Mt)=>`<div style="--k:${Mt}"><dt>${Oe(lt.k)}</dt><dd>${Oe(lt.v)}</dd></div>`).join(""),T.exSpecs.hidden=!be.specs.length,je(T.exFix,be.fixes,"ol"),je(T.exAmc,be.amc,"ul"),T.exEng.hidden=!be.engineer,T.exEng.querySelector("p").textContent=be.engineer;const ht=(lt,Mt)=>{const Wt=Mt>=0&&Mt<s;lt.hidden=!Wt,Wt&&(lt.querySelector(".esu-ex-nl").textContent=r.steps[Mt].name,lt.setAttribute("aria-label",`${Mt<D?"Previous":"Next"} machine: ${r.steps[Mt].name}`))};ht(T.exPrev,D-1),ht(T.exNext,D+1),T.ex.classList.remove("is-in"),T.ex.offsetWidth,T.ex.classList.add("is-in"),T.ex.querySelector(".esu-ex-body").scrollTop=0}try{f?.state?.esu&&f.replaceState(null,"",window.location.href)}catch{}function rt(){if(f)try{const D=new URL(window.location.href);if(!D.searchParams.has("step"))return;D.searchParams.delete("step"),f.replaceState(f.state,"",D.pathname+(D.search==="?"?"":D.search)+D.hash)}catch{}}rt();function Lt(D){try{f?.pushState({esu:D},"",window.location.href)}catch{}}function Je(D=1){try{f?.state?.esu&&(u=!0,f.go(-D))}catch{u=!1}}d(window,"popstate",()=>{u?u=!1:h?yo({fromPop:!0}):a.overlay==="menu"?li({fromPop:!0}):a.overlay==="explore"&&Dn({fromPop:!0}),rt()});let yt=0;const Jt=()=>{yt=performance.now()+400};function Ti(){a.phase!=="home"||a.overlay||(_e=document.activeElement,a.overlay="explore",qe(a.step),N.dataset.overlay="explore",Z(),m("click","explore"),p("explore:open",{index:a.step}),Lt("explore"),requestAnimationFrame(()=>T.exClose.focus({preventScroll:!0})),Jt())}function Dn({fromPop:D=!1}={}){a.overlay==="explore"&&(T.ex.classList.remove("is-in"),a.overlay=null,N.dataset.overlay="none",Z(),m("click","close"),p("explore:close",{index:a.step}),D||Je(),ga(T.dial),Jt())}let qn=0,Xi=null;try{Xi=new Intl.DateTimeFormat("en-GB",{timeZone:"Asia/Kolkata",hour:"2-digit",minute:"2-digit",hour12:!1})}catch{Xi=null}function _o(){Xi&&(T.menuClock.textContent=` · ${Xi.format(new Date)} IST`)}function cs(){a.phase!=="home"||a.overlay||(_e=document.activeElement,a.overlay="menu",N.dataset.overlay="menu",T.menuBtn.setAttribute("aria-expanded","true"),Z(),m("click","menu"),p("menu:open"),Lt("menu"),_o(),clearInterval(qn),qn=setInterval(_o,15e3),T.menuLinks.forEach((D,J)=>{const be=D.querySelector(".esu-menu-lbl");Ni(be,r.menu[J].label,{reduced:o,duration:.5,delay:.18+J*.06,scramble:.3})}),T.menuScroll.scrollTop=0,Er(),requestAnimationFrame(()=>T.menuClose.focus({preventScroll:!0})),Jt())}function Er(){const D=T.menuFoot.getBoundingClientRect().height;D&&T.menu.style.setProperty("--esu-menu-foot",`${Math.ceil(D)}px`)}function li({fromPop:D=!1}={}){if(a.overlay!=="menu")return;const J=h?2:1;xo(),a.overlay=null,N.dataset.overlay="none",T.menuBtn.setAttribute("aria-expanded","false"),clearInterval(qn),Z(),m("click","close"),p("menu:close"),D||Je(J),ga(T.menuBtn),Jt()}function us(D){T.pageKicker.textContent=D.kicker||D.label,T.pageKicker.hidden=!(D.kicker||D.label),Ni(T.pageH,D.headline,{reduced:o,duration:.7,delay:.2}),T.pageLead.textContent=D.lead,T.pageLead.hidden=!D.lead,T.pageCtas.innerHTML=D.ctas.slice(0,2).map((J,be)=>`<a class="esu-btn${be?"":" is-primary"}" href="${Oe(J.href)}" data-sfx="cta"><span>${Oe(J.label)}</span>${hi("arrow")}</a>`).join(""),T.pageCtas.hidden=!D.ctas.length,T.pageSpecs.innerHTML=D.specs.slice(0,4).map((J,be)=>`<div style="--k:${be}"><dt>${Oe(J.k)}</dt><dd>${Oe(J.v)}</dd></div>`).join(""),T.pageSpecs.hidden=!D.specs.length,T.pageRight.innerHTML=D.sections.map((J,be)=>`<section class="esu-ex-sec" style="--j:${be}">${J.title?`<h3>${Oe(J.title)}</h3>`:""}${J.items.length?`<ul>${J.items.map((je,ht)=>`<li style="--k:${ht}"><span class="esu-li-n" aria-hidden="true">${or(ht+1)}</span><span>${Oe(je)}</span></li>`).join("")}</ul>`:`<p>${Oe(J.text)}</p>`}</section>`).join(""),T.page.classList.remove("is-in"),T.page.offsetWidth,T.page.classList.add("is-in"),T.pageBody.scrollTop=0}function ma(D){const J=r.pages[D];if(!J||a.overlay!=="menu"||h===D)return!1;const be=!h;return h=D,N.dataset.page=D,us(J),T.menuNav.inert=!0,T.menuSide.inert=!0,T.page.inert=!1,be&&Lt("page"),requestAnimationFrame(()=>T.pageBack.focus({preventScroll:!0})),Jt(),!0}function xo(){if(!h)return"";const D=h;return h="",N.dataset.page="none",T.menuNav.inert=!1,T.menuSide.inert=!1,T.page.inert=!0,T.page.classList.remove("is-in"),D}function yo({fromPop:D=!1}={}){const J=xo();if(!J)return;m("click","close"),D||Je();const be=T.menuLinks.find(je=>je.dataset.page===J);requestAnimationFrame(()=>(be||T.menuClose).focus({preventScroll:!0})),Jt()}function ga(D){const J=_e&&N.contains(_e)&&!_e.closest("[inert]")?_e:D;_e=null,requestAnimationFrame(()=>J?.focus?.({preventScroll:!0}))}let Tr=0,L=0,Y=a.sound?1:0;function oe(){const D=[];for(let J=0;J<=32;J+=1){const be=Math.sin(J/32*Math.PI),je=4+Math.sin(J*.62+L)*2.4*be*Y;D.push(`${J} ${je.toFixed(2)}`)}T.soundPath.setAttribute("d",`M${D.join("L")}`)}let ae=0;function j(){Tr=0;const D=a.sound?1:0;!(ae++&1)&&!a.overlay&&(Y+=(D-Y)*.15,L+=o?0:.18,oe());const J=Math.abs(D-Y)<.01;(a.sound&&!o&&!document.hidden&&a.phase==="home"||!J)&&(Tr=requestAnimationFrame(j))}function Ce(){Tr||(Tr=requestAnimationFrame(j))}function Ue(){T.sound.setAttribute("aria-pressed",String(a.sound)),T.soundSt._chars?fi(T.soundSt,a.sound?x.on:x.off,{reduced:o,duration:.25,outDuration:.12}):rr(T.soundSt,a.sound?x.on:x.off),N.classList.toggle("is-muted",!a.sound),Ce()}function ke(){a.sound=!a.sound,wM(a.sound),Ue(),m("click","sound"),p("sound:toggle",{on:a.sound})}Ue(),oe(),d(T.menuBtn,"click",()=>a.overlay==="menu"?li():cs()),d(T.menuClose,"click",()=>li()),d(T.exClose,"click",()=>Dn()),d(T.exPrev,"click",()=>{m("click","prev"),B(a.step-1,"nav")}),d(T.exNext,"click",()=>{m("click","next"),B(a.step+1,"nav")}),d(T.ex,"click",D=>{const J=T.ex.querySelector(".esu-ex-body");J&&getComputedStyle(J).display==="block"||(D.target===T.ex||D.target===J)&&Dn()}),d(N,"click",D=>{D.detail&&performance.now()<yt&&(D.preventDefault(),D.stopImmediatePropagation())},!0),d(T.menu,"click",D=>{const J=D.target;(J===T.menu||J===T.menuScroll||J.closest(".esu-menu-bg")||J.classList.contains("esu-menu-nav"))&&li()}),d(T.dial,"click",()=>{T.dial.classList.remove("is-pulse"),T.dial.offsetWidth,T.dial.classList.add("is-pulse"),Ti()}),d(T.dial,"pointerenter",()=>Qi(T.dialLabel,{reduced:o})),d(T.dial,"focus",()=>Qi(T.dialLabel,{reduced:o})),[T.prev,T.next].forEach(D=>d(D,"pointerenter",()=>{D.disabled||Qi(D.querySelector(".esu-nav-l"),{reduced:o})})),d(T.prev,"click",()=>{m("click","prev"),B(a.step-1,"nav")}),d(T.next,"click",()=>{m("click","next"),B(a.step+1,"nav")}),T.glyphs.forEach(D=>d(D,"click",()=>{m("click","glyph"),B(Number(D.dataset.step),"nav")})),d(T.mode,"click",()=>{m("click","mode"),Te(a.mode==="story"?"timeline":"story")}),d(T.sound,"click",ke),d(T.menuBtn,"pointerenter",()=>Qi(T.menuBtnL,{reduced:o})),T.menuLinks.forEach(D=>{const J=D.querySelector(".esu-menu-lbl");d(D,"pointerenter",()=>Qi(J,{reduced:o,duration:.36})),d(D,"focus",()=>Qi(J,{reduced:o,duration:.36})),d(D,"click",be=>{m("click","link"),D.dataset.page&&r.pages[D.dataset.page]&&(be.preventDefault(),ma(D.dataset.page))})}),d(T.pageBack,"click",()=>yo()),d(N,"click",D=>{D.target.closest?.(".esu-btn, .esu-req")&&m("click","cta")});let He=null;d(N,"pointerover",D=>{if(D.pointerType!=="mouse")return;const J=D.target.closest?.("[data-sfx]");J!==He&&(He=J,!(!J||J.disabled||J.closest("[inert]"))&&J!==T.intro&&m("hover",J.dataset.sfx))});function Ze(D){if(D.defaultPrevented||D.metaKey||D.ctrlKey||D.altKey||nM(D.target))return;const J=D.key;if(a.overlay){const je=a.overlay==="menu"?T.menu:T.ex;J==="Escape"?(D.preventDefault(),h?yo():a.overlay==="menu"?li():Dn()):J==="Tab"?tM(je,D):a.overlay==="explore"&&(J==="ArrowLeft"||J==="ArrowRight")?(D.preventDefault(),B(a.step+(J==="ArrowRight"?1:-1),"key"),(document.activeElement?.hidden||!T.ex.contains(document.activeElement))&&T.exClose.focus({preventScroll:!0})):(J==="m"||J==="M")&&a.overlay==="menu"?(D.preventDefault(),li()):(J==="s"||J==="S")&&(D.preventDefault(),ke());return}if(a.phase==="intro"){(J==="Enter"||J===" ")&&a.loaded&&(D.preventDefault(),me({viaKey:!0}));return}if(a.phase!=="home")return;const be=D.target?.closest?.('button, a, [role="slider"]');switch(J){case"ArrowLeft":D.preventDefault(),B(a.step-1,"key");break;case"ArrowRight":D.preventDefault(),B(a.step+1,"key");break;case"Enter":be||(D.preventDefault(),Ti());break;case"m":case"M":D.preventDefault(),cs();break;case"s":case"S":D.preventDefault(),ke();break;case"t":case"T":D.preventDefault(),Te(a.mode==="story"?"timeline":"story");break}}d(window,"keydown",Ze);let $e=0,Ge=!1,ct=0,vt=0,Tt=0;d(window,"wheel",D=>{if(a.phase!=="home"||a.overlay||$)return;const J=D.deltaMode===1?16:D.deltaMode===2?window.innerHeight:1,be=(Math.abs(D.deltaY)>Math.abs(D.deltaX)?D.deltaY:D.deltaX)*J,je=Math.abs(be),ht=performance.now();clearTimeout(ct),ct=setTimeout(()=>{$e=0,Ge=!1,vt=0},240),Ge&&ht>Tt&&je>12&&je>vt*2&&(Ge=!1),vt=je,!(Ge||ht<Tt)&&($e+=be,!(Math.abs($e)<60)&&(B(a.step+Math.sign($e),"nav")&&m("click",$e>0?"next":"prev"),$e=0,Ge=!0,Tt=ht+450))},{passive:!0});const gn=50,ut=1e3;let Be=null;d(window,"touchstart",D=>{if(a.phase!=="home"||a.overlay||$||D.touches.length!==1){Be=null;return}if(D.target.closest?.(".esu-tl-track, .esu-glyphs, button, a")){Be=null;return}Be={x:D.touches[0].clientX,y:D.touches[0].clientY,t:performance.now()}},{passive:!0}),d(window,"touchcancel",()=>{Be=null},{passive:!0}),d(window,"touchend",D=>{if(!Be)return;const J=D.changedTouches[0],be=J.clientX-Be.x,je=J.clientY-Be.y,ht=performance.now()-Be.t;Be=null,!(a.phase!=="home"||a.overlay||D.touches.length)&&ht<=ut&&Math.abs(be)>=gn&&Math.abs(be)>Math.abs(je)*1.4&&B(a.step+(be<0?1:-1),"nav")&&m("click",be<0?"next":"prev")},{passive:!0});let Vt="";function ot(){const D=window.innerWidth,J=window.innerHeight,be=getComputedStyle(T.stage).display==="flex";let je=0,ht=J;if(be){qi();for(const Wt of[T.menuBtn,T.mode,T.brand]){const ui=Wt.getBoundingClientRect();ui.height&&ui.bottom<J/2&&(je=Math.max(je,ui.bottom))}ht=T.dial.getBoundingClientRect().top}const lt={w:D,h:J,stacked:be,top:Math.round(je),bottom:Math.round(ht)},Mt=`${D}x${J}:${be}:${lt.top}:${lt.bottom}`;Mt!==Vt&&(Vt=Mt,p("hud:frame",lt))}v("load:done",ot);let Yt=null;function qi(){const D=T.text.getBoundingClientRect().width;if(!D)return;Yt||(Yt=Xr("p",{class:"esu-text esu-text-probe","aria-hidden":"true"}),T.story.appendChild(Yt)),Yt.style.width=`${D}px`;let J=0;for(const be of r.steps)rr(Yt,be.story),J=Math.max(J,Yt.getBoundingClientRect().height);Yt.textContent="",T.story.style.setProperty("--esu-story-h",`${Math.ceil(J)}px`)}const an=[T.ex.querySelector(".esu-ex-body"),T.pageBody],hs=new Map;let Rt=!1;an.forEach(D=>d(D,"scroll",()=>{if(Rt)return;const J=D.scrollHeight-D.clientHeight;hs.set(D,J>0?D.scrollTop/J:0)},{passive:!0}));function ci(){for(const D of an){const J=hs.get(D),be=D.scrollHeight-D.clientHeight;J&&be>0&&(D.scrollTop=Math.round(J*be))}}let Ar=0;d(window,"resize",()=>{Rt=!0,!Ar&&(Ar=requestAnimationFrame(()=>{Ar=0,de(),ci(),ot(),a.overlay==="menu"&&Er(),requestAnimationFrame(()=>{Rt=!1})}))}),d(document,"visibilitychange",()=>{!document.hidden&&a.phase==="home"&&Ce()}),v("quality:set",D=>{a.tier=D?.tier||"high",N.dataset.tier=a.tier}),k("loading"),i&&re();function Mn({step:D=a.step}={}){if(a.phase==="home"){B(D,"auto");return}a.loaded=!0,a.target=a.shown=1,ce&&(cancelAnimationFrame(ce),ce=0),ee=!0,a.step=Yn(D|0,0,s-1),N.classList.add("is-loader-out","is-entering"),p("intro:enter"),a.sound||p("sound:toggle",{on:!1}),a.step&&p("step:change",{index:a.step,prev:0,source:"auto"}),k("home"),q()}return{destroy(){c=!0,l.forEach(D=>D()),cancelAnimationFrame(ce),cancelAnimationFrame(Tr),cancelAnimationFrame(Me),clearInterval(qn),clearTimeout(ct),ue?.kill(),he?.kill(),Ae?.destroy(),N.remove()},enter(){a.loaded||re(),a.phase==="intro"&&me()},jumpHome:Mn,setStep(D,J="nav"){return B(D,J)},setMode:Te,openExplore:Ti,closeExplore:Dn,openMenu:cs,closeMenu:li,get state(){return{phase:a.phase,mode:a.mode,step:a.step,overlay:a.overlay,sound:a.sound}}}}const xm=.15,AM=.05,CM=1.75*xm,RM=1*AM/xm,Ya=.316,PM=.5,Zc=.035,LM=.03,DM=.022,wn=n=>440*Math.pow(2,(n-69)/12),ar=(n,e,t)=>Math.min(t,Math.max(e,n)),jn=[{id:"dawn",time:"05:40",name:"Dmaj9",root:50,chord:[57,64,66,73],wave:"warm",cutoff:2800,shimmer:.85,level:.95,air:{f:2600,q:.6,g:.12},bells:[74,76,78,81,85]},{id:"morning",time:"09:00",name:"Aadd9",root:45,chord:[64,71,73,76],wave:"warm",cutoff:3800,shimmer:1,level:1,air:{f:3200,q:.55,g:.12},bells:[76,81,83,85,88]},{id:"noon",time:"13:00",name:"Gmaj7#11",root:43,chord:[62,66,69,73],wave:"warm",cutoff:3200,shimmer:.75,level:1.1,air:{f:2200,q:.5,g:.13},bells:[74,78,79,81,86]},{id:"dusk",time:"17:30",name:"Em9",root:52,chord:[55,62,66,71],wave:"warm",cutoff:2400,shimmer:.75,level:.98,air:{f:2100,q:.6,g:.13},bells:[71,74,76,78,83]},{id:"night",time:"21:00",name:"Bm9",root:47,chord:[57,62,66,73],wave:"soft",cutoff:1800,shimmer:.7,level:.9,air:{f:1800,q:.65,g:.12},bells:[71,73,74,78,81]},{id:"deepnight",time:"02:00",name:"F#m11",root:42,chord:[57,61,64,71],wave:"soft",cutoff:1600,shimmer:.65,level:1.13,air:{f:1700,q:.7,g:.115},bells:[69,71,73,76,78]}];function IM(n){let e=n>>>0;return()=>{e=e+1831565813>>>0;let t=e;return t=Math.imul(t^t>>>15,t|1),t^=t+Math.imul(t^t>>>7,t|61),((t^t>>>14)>>>0)/4294967296}}function UM(n,e,t){const i=n.sampleRate,r=Math.floor(i*e),s=Math.floor(i*.08),o=n.createBuffer(2,r,i),a=new Float32Array(r+s);for(let l=0;l<2;l++){let c=0,u=0,h=0,f=0,d=0,v=0,g=0;for(let m=0;m<a.length;m++){const x=t()*2-1;c=.99886*c+x*.0555179,u=.99332*u+x*.0750759,h=.969*h+x*.153852,f=.8665*f+x*.3104856,d=.55*d+x*.5329522,v=-.7616*v-x*.016898,a[m]=(c+u+h+f+d+v+g+x*.5362)*.11,g=x*.115926}const p=o.getChannelData(l);for(let m=0;m<r;m++)p[m]=a[m];for(let m=0;m<s;m++){const x=m/s;p[m]=a[m]*x+a[r+m]*(1-x)}}return o}function NM(n,{seed:e=1}={}){const t=IM(e),i=()=>n.currentTime,r=(B=0)=>{const q=n.createGain();return q.gain.value=B,q},s=(B,q)=>{const V=n.createOscillator();return V.type=B,V.frequency.value=q,V},o=(B,q,V=.7)=>{const A=n.createBiquadFilter();return A.type=B,A.frequency.value=q,A.Q.value=V,A},a=B=>{const q=n.createDelay(.2);return q.delayTime.value=B,q},l=(B=0)=>{if(!n.createStereoPanner)return r(1);const q=n.createStereoPanner();return q.pan.value=ar(B,-1,1),q},c=B=>{try{B.automationRate="k-rate"}catch{}return B},u=(B,q)=>{try{B.stop(q)}catch{}},h=B=>n.createPeriodicWave(new Float32Array(B.length),new Float32Array(B)),f={warm:h([0,1,.5,.3,.19,.12,.075,.045,.027,.016,.01]),soft:h([0,1,.3,.13,.06,.028,.012]),root:h([0,1,.8,.62,.46,.33,.22,.14,.085,.05,.03,.017])},d=UM(n,3,t),v=r(0);c(v.gain);const g=n.createWaveShaper(),p=new Float32Array(2049);for(let B=0;B<p.length;B++){const q=B/(p.length-1)*2-1,V=Math.abs(q),A=PM-Ya;p[B]=V<Ya?q:Math.sign(q)*(Ya+A*Math.tanh((V-Ya)/A))}g.curve=p,v.connect(g),g.connect(n.destination);const m=n.createAnalyser();m.fftSize=2048,g.connect(m);const x=r(1);x.channelCount=1,x.channelCountMode="explicit";const _=r(.7);_.connect(v);{const B=($,ne,te)=>{const ve=a(ne),ue=r(te),Me=r(-te),Re=r(1-te*te);return $.forEach(de=>{de.connect(ve),de.connect(Me)}),ve.connect(ue),ue.connect(ve),ve.connect(Re),[Me,Re]},V=o("highpass",160,-3),A=a(.015);x.connect(V),V.connect(A);const E=B(B([A],.0049,.6),.0113,.55),z=n.createChannelMerger(2);z.connect(_),[[.0371,.0457,.0533],[.0397,.0479,.0557]].forEach(($,ne)=>{const te=r(1/$.length);$.forEach(ve=>{const ue=a(ve),Me=o("lowpass",4200,-3),Re=r(Math.pow(10,-3*ve/2.7));E.forEach(de=>de.connect(ue)),ue.connect(Me),Me.connect(Re),Re.connect(ue),ue.connect(te)}),B([te],ne?.0067:.0059,.5).forEach(ve=>ve.connect(z,0,ne))})}const y=r(1),C=o("highpass",110,.71),M=o("lowpass",18e3,.5);c(M.frequency);const w=r(1);c(w.gain),y.connect(C),C.connect(M),M.connect(w),w.connect(v);const P=r(.55);w.connect(P),P.connect(x);const I=r(RM);I.connect(v);const S=r(.32);I.connect(S),S.connect(x);const b=(B,q,V,A,E,z=0)=>({param:B,base:q,depth:V,tau:A,gap:E,min:z,next:0});function N(B,q){for(const V of B)for(V.next<i()&&(V.next=i());V.next<q;){const A=Math.max(V.min,V.base+(t()*2-1)*V.depth);V.param.setTargetAtTime(A,V.next,V.tau),V.next+=V.gap[0]+t()*(V.gap[1]-V.gap[0])}}let R=0,H=[];function T(B,q,V){const A=jn[B],E=r(0);c(E.gain),E.gain.setValueAtTime(0,q),E.gain.setTargetAtTime(A.level,q,Math.max(.02,V/4.2)),E.connect(y);const z=o("lowpass",A.cutoff,.6);c(z.frequency),z.connect(E);const $=[l(-.8),l(.8)];$.forEach(Re=>Re.connect(z));const ne=[],te=[b(z.frequency,A.cutoff,A.cutoff*.3,2.4,[3,6.5],300)],ve=r(Zc);c(ve.gain),ve.connect(z),te.push(b(ve.gain,Zc,Zc*.25,2.2,[3,6])),[[A.root,"root"],...A.chord.map(Re=>[Re,A.wave])].forEach(([Re,de],Ee)=>{const Ne=LM*(1-(Ee-1)*.06);[-1,1].forEach((Ve,Pe)=>{const Xe=n.createOscillator();Xe.setPeriodicWave(f[de]),Xe.frequency.value=wn(Re),Xe.detune.value=Ve*(3+t()*4);let We=Ee===0?ve:null;We||(We=r(Ne),c(We.gain),We.connect($[Pe]),te.push(b(We.gain,Ne,Ne*.5,1.6+t()*1.6,[2.2,5.5]))),Xe.connect(We),ne.push(Xe)})});const ue=n.createChannelMerger(2);ue.connect(E),A.chord.slice(-2).forEach((Re,de)=>{const Ee=DM*A.shimmer,Ne=r(Ee*.4);c(Ne.gain);const Ve=s("sine",wn(Re+12));Ve.detune.value=(t()-.5)*6,Ve.connect(Ne),Ne.connect(ue,0,de),te.push(b(Ne.gain,Ee,Ee,3+t()*3,[4,9])),ne.push(Ve)}),ne.forEach(Re=>Re.start(q)),te.forEach(Re=>{Re.next=q+.4+t()*1.6});const Me={out:E,sources:ne,moves:te,released:!1,done:!1};return Me.release=(Re,de)=>{if(Me.released)return;Me.released=!0,Me.moves=[],E.gain.cancelScheduledValues(Re),E.gain.setTargetAtTime(0,Re,Math.max(.02,de/3));const Ee=Re+de*2.2+.2;ne.forEach(Ne=>u(Ne,Ee))},Me.kill=Re=>{Me.released=!0,Me.moves=[],E.gain.cancelScheduledValues(Re),E.gain.setTargetAtTime(0,Re,.16),ne.forEach(de=>u(de,Re+1.2))},ne[0].onended=()=>{Me.done=!0;try{E.disconnect()}catch{}H=H.filter(Re=>Re!==Me)},Me}const k={src:null,bp:o("bandpass",jn[0].air.f,jn[0].air.q),lp:o("lowpass",6500,.5),out:r(0),boost:r(1)};[k.bp.frequency,k.bp.Q,k.out.gain,k.boost.gain].forEach(c),k.bp.connect(k.lp),k.lp.connect(k.out),k.out.connect(k.boost),k.boost.connect(y);const Z=[b(k.out.gain,0,0,1.4,[2,5]),b(k.bp.frequency,1e3,0,2.2,[3,7],200)];function K(B){k.src||(k.src=n.createBufferSource(),k.src.buffer=d,k.src.loop=!0,k.src.connect(k.bp),k.src.start(B,t()*2))}function pe(B,q,V){const A=jn[B].air;[[k.bp.frequency,A.f],[k.bp.Q,A.q],[k.out.gain,A.g]].forEach(([E,z])=>{E.cancelScheduledValues(q),E.setTargetAtTime(z,q,V)}),Object.assign(Z[0],{base:A.g,depth:A.g*.5,next:q+V*2.5}),Object.assign(Z[1],{base:A.f,depth:A.f*.3,next:q+V*2.5})}function ce(B){N(Z,B),H.forEach(q=>N(q.moves,B))}let W=-1/0;function re(B,{fade:q=3.4,initial:V=!1}={}){B=ar(B|0,0,jn.length-1);const A=i(),E=!V&&A-W<.9;W=A;const z=H.filter($=>!$.done);z.slice(0,Math.max(0,z.length-2)).forEach($=>$.kill(A)),z.forEach($=>$.release(A,V?.4:E?.9:q*1.15)),H.push(T(B,A,E?.9:q)),K(A),pe(B,A,V?.05:q/3),R=B,ce(A+6)}function Ae(B,q=.2){const V=i(),A=ar(B,0,1);M.frequency.setTargetAtTime(A<=0?18e3:18e3*Math.pow(800/18e3,A),V,q),w.gain.setTargetAtTime(1-.3*A,V,q*1.4)}function ee(B){const q=ar(B,0,1);k.boost.gain.setTargetAtTime(1+3*q,i(),q>0?.05:.3)}function F(B,q,V,A,E){const z=r(0);return z.gain.setValueAtTime(0,B),z.gain.linearRampToValueAtTime(q,B+V),z.gain.setTargetAtTime(0,B+V,A/5),z.connect(E),z}function xe(B,q){const V=n.createBufferSource();return V.buffer=d,V.start(B,t()*Math.max(0,d.duration-q-.2),q+.05),V}function G(B,q,V,A,E,z=y){const $=l(E);$.connect(z);const ne=F(B,V,.03,A,$),te=s("sine",q),ve=s("sine",q*2),ue=r(0);ue.gain.setValueAtTime(q*.42,B),ue.gain.setTargetAtTime(0,B,.09),ve.connect(ue),ue.connect(te.frequency),te.connect(ne);const Me=s("sine",q*2);Me.connect(F(B,V*.16,.02,A*.5,$));const Re=s("sine",q*3);Re.connect(F(B,V*.1,.012,A*.3,$));const de=B+A+.3;[te,ve,Me,Re].forEach(Ee=>{Ee.start(B),Ee.stop(de)})}function he(B=i()+.05,q=R,V=Math.floor(t()*3)){const A=jn[q].bells,E=.07*(q>=4?.8:1),z=(t()-.5)*.8;if(V===0){const $=Math.floor(t()*3);G(B,wn(A[$]),E,1.6,z),G(B+.52+t()*.2,wn(A[$+2]),E*.85,2.2,z*.6)}else if(V===1)G(B,wn(A[Math.floor(t()*A.length)]),E*1.1,2.6,z);else{const $=2+Math.floor(t()*3);G(B,wn(A[$]),E,1.5,z),G(B+.75+t()*.25,wn(A[$-2]),E*.8,2.4,-z*.5)}}function me(B=3300,q=.03){const V=i()+.004,A=s("sine",B*(.97+t()*.06)),E=r(0);E.gain.setValueAtTime(1e-4,V),E.gain.exponentialRampToValueAtTime(q,V+.002),E.gain.exponentialRampToValueAtTime(1e-4,V+.04),A.connect(E),E.connect(I),A.start(V),A.stop(V+.06);const z=xe(V,.03),$=o("bandpass",5200,1.4),ne=r(0);ne.gain.setValueAtTime(1e-4,V),ne.gain.exponentialRampToValueAtTime(.07,V+.001),ne.gain.exponentialRampToValueAtTime(1e-4,V+.014),z.connect($),$.connect(ne),ne.connect(I)}function fe(B,q,V,A){[[1,1,1.2],[2.32,.34,.55],[4.25,.14,.25],[6.63,.05,.12]].forEach(([E,z,$])=>{const ne=s("sine",q*E);ne.connect(F(B,V*z,.0015,$,A)),ne.start(B),ne.stop(B+$+.3)})}function De(B=""){const q=i()+.004,V=jn[R].bells,A=B.toLowerCase();if(A==="knob")return me(1700,.045);if(A==="close")return fe(q,wn(V[0]),.047,I);const E=/glyph|prev|next|menu|explore|mode|sound/.test(A);fe(q,wn(V[0]+12),E?.035:.055,I),/cta|primary|secondary|request|join/.test(A)?fe(q+.085,wn(V[2]+12),.044,I):A==="mode"&&fe(q+.07,wn(V[2]+12),.024,I)}function se(B=R,q=!1){const V=i()+.01,A=wn(jn[B].bells[q?2:4]),E=q?5:15,z=q?.1:.32;for(let te=0;te<E;te++){const ve=te/(E-1),ue=V+z*Math.pow(ve,.9)+(t()-.5)*.012,Me=ar(A*Math.pow(2,(t()*2-1)*(1-ve)*1.7),260,7200),Re=.012+t()*.02,de=l((t()-.5)*1.2*(1-ve));de.connect(I);const Ee=r(0);Ee.gain.setValueAtTime(1e-4,ue),Ee.gain.exponentialRampToValueAtTime(.06*(.55+.45*ve),ue+.0015),Ee.gain.exponentialRampToValueAtTime(1e-4,ue+Re),Ee.connect(de);const Ne=s(t()<.5?"sine":"triangle",Me);Ne.connect(Ee),Ne.start(ue),Ne.stop(ue+Re+.02)}const $=V+z+.015,ne=s("sine",A);if(ne.connect(F($,q?.04:.07,.004,q?.18:.5,I)),ne.start($),ne.stop($+.8),!q){const te=xe(V,z+.05),ve=o("bandpass",4800,1.1),ue=r(0);ue.gain.setValueAtTime(0,V),ue.gain.linearRampToValueAtTime(.08,V+z*.4),ue.gain.linearRampToValueAtTime(0,V+z+.04),te.connect(ve),ve.connect(ue),ue.connect(I)}}function U({from:B,to:q,dur:V,level:A,panFrom:E=0,panTo:z=0}){const $=i()+.005,ne=xe($,V+.1),te=o("bandpass",B,.85);te.frequency.setValueAtTime(B,$),te.frequency.exponentialRampToValueAtTime(q,$+V);const ve=r(0);ve.gain.setValueAtTime(0,$),ve.gain.linearRampToValueAtTime(A,$+V*.42),ve.gain.linearRampToValueAtTime(0,$+V);const ue=l(E);ue.pan&&(ue.pan.setValueAtTime(E,$),ue.pan.linearRampToValueAtTime(z,$+V)),ne.connect(te),te.connect(ve),ve.connect(ue),ue.connect(I)}function Se(B,q,V,A){const E=i()+.01,z=r(0);z.gain.setValueAtTime(0,E),z.gain.linearRampToValueAtTime(q,E+V),z.gain.setTargetAtTime(0,E+V,A/5),z.connect(I);const $=n.createOscillator();$.setPeriodicWave(f.soft),$.frequency.value=wn(B);const ne=s("sine",wn(B+7)),te=r(.35);$.connect(z),ne.connect(te),te.connect(z),[$,ne].forEach(ve=>{ve.start(E),ve.stop(E+V+A+.5)})}const ye=B=>{let q=jn[R].root;for(;q<B;)q+=12;return q};return{ctx:n,master:v,analyser:m,sfx:{hover:()=>me(),click:De,chirp:se,chime:()=>he(i()+.02),exploreOpen(){U({from:380,to:2600,dur:.8,level:.22,panFrom:-.35,panTo:.35}),Se(ye(62),.04,.22,1.4)},exploreClose(){U({from:2600,to:320,dur:.65,level:.3,panFrom:.35,panTo:-.35})},menuOpen(){U({from:600,to:3600,dur:.55,level:.3,panFrom:.3,panTo:-.1})},menuClose(){U({from:3400,to:480,dur:.5,level:.28,panFrom:-.1,panTo:.3})},reveal(){U({from:180,to:1900,dur:1.7,level:.24,panFrom:-.2,panTo:.2}),Se(ye(55),.065,1.1,5)}},chime:he,setStep:re,setMuffle:Ae,setScrub:ee,tick:ce,get mood(){return R},set mood(B){R=ar(B|0,0,jn.length-1)}}}function FM({bus:n}={}){const e=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext),t=typeof matchMedia=="function"&&matchMedia("(prefers-reduced-motion: reduce)").matches;let i=null,r=null,s=!1,o=!0,a=typeof document<"u"&&document.hidden,l=0,c=!1,u=!1,h=0,f=0,d=0,v=0,g=0,p=0,m=null,x=!1,_=null,y=!1;const C=[],M=()=>!!r&&s&&o&&!a&&!y;function w(){if(r||!e||y)return!!r;const F=performance.now();try{i=new e({latencyHint:"interactive"})}catch{try{i=new e}catch{return!1}}const xe=performance.now();return r=NM(i,{seed:Math.random()*1e9|0}),r.mood=l,_={context:Math.round(xe-F),graph:Math.round(performance.now()-xe),at:Math.round(F)},!0}function P(){!x||!r||!s||(x=!1,r.setStep(l,{fade:1.2}))}function I(F=.25){if(!r)return;const xe=o&&s&&!a?CM:0;r.master.gain.setTargetAtTime(xe,i.currentTime,F)}const S=typeof window>"u"||"webkitAudioContext"in window||!(typeof navigator<"u"&&navigator.userActivation);let b=null,N=!1;const R=["pointerdown","pointerup","keydown"],H=()=>{typeof window<"u"&&R.forEach(F=>window.removeEventListener(F,T,!0))};function T(F){if(!F.isTrusted||y)return;if(r||!e){H();return}const xe=typeof navigator<"u"?navigator.userActivation:null;xe&&!xe.isActive||(H(),w())}typeof window<"u"&&e&&R.forEach(F=>window.addEventListener(F,T,!0));function k(){return y?Promise.resolve(!1):r||S?Z():(b||(b=new Promise(F=>{const xe=()=>{b=null,F(Z()),N&&ce()};typeof requestIdleCallback=="function"?requestIdleCallback(xe,{timeout:250}):setTimeout(xe,60)})),b)}function Z(){if(!w())return Promise.resolve(!1);try{const F=i.createBufferSource();F.buffer=i.createBuffer(1,1,i.sampleRate),F.connect(i.destination),F.start(0)}catch{}return i.state==="running"?Promise.resolve(!0):a||!o&&s?Promise.resolve(!1):i.resume().then(()=>!0,()=>!1)}function K(F){clearTimeout(d),d=setTimeout(()=>{M()&&!u&&r.chime(),K(13e3+Math.random()*14e3)},F)}function pe(F,xe=0){clearTimeout(g),i&&(F?g=setTimeout(()=>{i&&i.state==="running"&&(a||!o)&&i.suspend().catch(()=>{})},xe):i.state!=="running"&&i.state!=="closed"&&i.resume().catch(()=>{}))}function ce(){s||!r||(s=!0,r.mood=l,I(.08),r.sfx.reveal(),r.setStep(l,{fade:4.5}),K(8e3+Math.random()*5e3),v=setInterval(()=>{r&&i.state==="running"&&r.tick(i.currentTime+6)},2500),(!o||a)&&pe(!0,600))}function W(){r&&r.setMuffle(u?1:c?.78:0,t?.08:.2)}const re={"load:done":()=>{},"intro:enter":()=>{N=!0,k(),ce()},"step:change":(F={})=>{const xe=ar((F.index??0)|0,0,jn.length-1),G=xe!==l;if(l=xe,!r||!s){r&&(r.mood=l);return}if(!G)return;if(!M()){x=!0;return}const he=F.source==="timeline";r.setStep(l,{fade:he?2.4:3.4});const me=performance.now();me-f>110&&(r.sfx.chirp(l,he||me-f<400),f=me)},"explore:open":()=>{c||(c=!0,M()&&r.sfx.exploreOpen(),W())},"explore:close":()=>{c&&(c=!1,M()&&r.sfx.exploreClose(),W())},"menu:open":()=>{u||(u=!0,M()&&r.sfx.menuOpen(),W())},"menu:close":()=>{u&&(u=!1,M()&&r.sfx.menuClose(),W())},"sound:toggle":F=>{o=F&&typeof F.on=="boolean"?F.on:!o,o?(s&&k(),pe(!1),P(),I(.35)):(I(.18),pe(!0,1400))},"ui:hover":()=>{const F=performance.now();!M()||F-h<45||(h=F,r.sfx.hover())},"ui:click":(F={})=>{M()&&r.sfx.click(String(F.kind||""))},"timeline:scrub":(F={})=>{if(!M()||typeof F.t!="number")return;const xe=performance.now();if(m){const G=Math.max(16,xe-m.time)/1e3;r.setScrub(ar(Math.abs(F.t-m.t)/G*.9,0,1))}m={t:F.t,time:xe},clearTimeout(p),p=setTimeout(()=>{m=null,r&&r.setScrub(0)},140)}};if(n)for(const[F,xe]of Object.entries(re))n.on(F,xe),C.push(()=>n.off(F,xe));const Ae=()=>{a=document.hidden,r&&(a?(I(.06),pe(!0,350)):(o&&(pe(!1),P()),I(.4)))};typeof document<"u"&&document.addEventListener("visibilitychange",Ae);function ee(){y||(y=!0,H(),C.forEach(F=>F()),C.length=0,clearTimeout(d),clearInterval(v),clearTimeout(g),clearTimeout(p),typeof document<"u"&&document.removeEventListener("visibilitychange",Ae),i&&i.state!=="closed"&&i.close().catch(()=>{}),i=null,r=null)}return{unlock:k,dispose:ee,debug:{get context(){return i},get analyser(){return r?r.analyser:null},get state(){return{context:i?i.state:"none",started:s,soundOn:o,hidden:a,step:l,exploreOpen:c,menuOpen:u,mood:jn[l].id,buildMs:_}},chime(){M()&&r.chime()}}}}function Mr(n){let e=n>>>0;return function(){e=e+1831565813|0;let i=Math.imul(e^e>>>15,1|e);return i=i+Math.imul(i^i>>>7,61|i)^i,((i^i>>>14)>>>0)/4294967296}}const Le=(n,e,t)=>e+(t-e)*n(),er=(n,e,t)=>n+(e-n)*t,OM=n=>n<0?0:n>1?1:n,kM=n=>n*n*(3-2*n),bh=(n,e,t)=>kM(OM((t-n)/(e-n))),$t=256;function Jc(n,e,t,i=.5,r=!1){const s=new Float32Array($t*$t);let o=1;for(let a=0;a<t;a++){const l=e<<a;if(l>$t/2)break;const c=new Float32Array(l*l);for(let h=0;h<c.length;h++)c[h]=n();const u=l/$t;for(let h=0;h<$t;h++){const f=h*u,d=Math.floor(f),v=f-d,g=v*v*v*(v*(v*6-15)+10),p=d%l*l,m=(d+1)%l*l;for(let x=0;x<$t;x++){const _=x*u,y=Math.floor(_),C=_-y,M=C*C*C*(C*(C*6-15)+10),w=y%l,P=(y+1)%l,I=c[p+w],S=c[p+P],b=c[m+w],N=c[m+P];let R=I+(S-I)*M+(b-I)*g+(I-S-b+N)*M*g;r&&(R=1-Math.abs(R*2-1)),s[h*$t+x]+=o*R}}o*=i}return ym(s)}function BM(n,e){const t=new Float32Array(e*e*2);for(let r=0;r<t.length;r++)t[r]=n();const i=new Float32Array($t*$t);for(let r=0;r<$t;r++){const s=(r+.5)/$t*e,o=Math.floor(s);for(let a=0;a<$t;a++){const l=(a+.5)/$t*e,c=Math.floor(l);let u=9;for(let h=-1;h<=1;h++)for(let f=-1;f<=1;f++){const d=c+f,v=o+h,g=(d%e+e)%e,m=((v%e+e)%e*e+g)*2,x=d+t[m]-l,_=v+t[m+1]-s,y=x*x+_*_;y<u&&(u=y)}i[r*$t+a]=Math.sqrt(u)}}return ym(i)}function ym(n){let e=1/0,t=-1/0;for(let r=0;r<n.length;r++)n[r]<e&&(e=n[r]),n[r]>t&&(t=n[r]);const i=1/Math.max(t-e,1e-6);for(let r=0;r<n.length;r++)n[r]=(n[r]-e)*i;return n}function zM(n=7){const e=Mr(n),t=Jc(e,4,6,.52),i=Jc(e,16,4,.55),r=Jc(e,8,5,.5,!0),s=BM(e,16),o=new Uint8Array($t*$t*4);for(let l=0;l<$t*$t;l++)o[l*4]=t[l]*255,o[l*4+1]=i[l]*255,o[l*4+2]=r[l]*255,o[l*4+3]=s[l]*255;const a=new Zy(o,$t,$t,Hn,on);return a.wrapS=a.wrapT=xl,a.magFilter=hn,a.minFilter=lr,a.generateMipmaps=!0,a.colorSpace=oi,a.needsUpdate=!0,a}const gl=10,En={rInner:3.05,rRim:3.62,rOuter:4.42,rimY:.56,waterY:.41,stepH:.17},jr=[0,1.45,0],Sm=2.5,HM=[jr[0],jr[1]+Sm/2,jr[2]],Rs={z:17.5,w:4.6,h:13,r0:1.1,r1:.34},vl=[{z:-1.4,w:7.9,h:16,r0:1.5,r1:.42,diag:0},{z:-9.6,w:6.6,h:14.8,r0:1.12,r1:.32,diag:1},{z:-18.8,w:5.9,h:12.8,r0:.95,r1:.28,diag:1},{z:-29.5,w:5.8,h:12.8,r0:.9,r1:.27,diag:1},{z:-41.5,w:6.1,h:13.2,r0:.9,r1:.27,diag:0},{z:-55.5,w:6.6,h:13.8,r0:.95,r1:.29,diag:0},{z:-72,w:7.2,h:14.4,r0:1,r1:.31,diag:0}],Mm=[[-12.5,-6],[13,-4],[-15.5,-15],[16,-13],[-12,-24],[12.5,-22.5],[-17,-33],[18,-36],[-13,-47],[14,-45],[-20,-58],[21,-62],[-24,-20],[25,-27],[-28,-42],[29,-48]],GM=[{x:-7.2,z:3.6,h:4.6,spread:3.4,lean:-.35,seed:11},{x:9.8,z:-4.8,h:4.8,spread:3.5,lean:.5,seed:23},{x:-12.5,z:-11,h:5,spread:3.2,lean:-.2,seed:37}],VM=[{x:-2.9,z:-6.6,r:1.5,h:2.3},{x:.8,z:-7.8,r:1.8,h:2.9},{x:3.6,z:-6.3,r:1.4,h:2.1},{x:-5.4,z:-8.8,r:1.9,h:3.1},{x:6,z:-9.2,r:2,h:3.3},{x:-1.6,z:-11.8,r:2.1,h:3.4},{x:-9.2,z:-1,r:1.4,h:1.2},{x:7.4,z:1.2,r:1.3,h:1.1},{x:11.5,z:-1.5,r:2,h:2.4},{x:-10.5,z:-6,r:1.8,h:2},{x:8.5,z:-14,r:2.2,h:2.6},{x:-7,z:-16.5,r:2,h:2.2},{x:3.5,z:-15.5,r:1.6,h:1.8},{x:-3.8,z:-21,r:2,h:2},{x:6,z:-24,r:2.4,h:2.6},{x:-8,z:-28,r:2.6,h:2.8},{x:2,z:-33,r:2.6,h:2.6}],Nl=[[-3,-5,1.5,1],[2.6,-12.5,2,.9],[-8.5,-15,2.6,.85],[5.4,-2.6,1.25,.8],[-1.2,4.6,1.05,.55],[8.5,-24,3,.75],[-5.5,-31,3.4,.7],[.8,-42,4,.65]],WM=[{x:-70,z:-360,w:34,floors:5},{x:12,z:-410,w:44,floors:7},{x:85,z:-380,w:28,floors:4},{x:-150,z:-420,w:30,floors:4}];function XM(n){const e=()=>({value:new st}),t=(r=0,s=1,o=0)=>({value:new O(r,s,o)}),i=(r=0)=>({value:r});return{uTime:i(0),uNoise:{value:n},uSkyTop:e(),uSkyHorizon:e(),uSkyGain:i(1),uCloudLit:e(),uCloudShadow:e(),uCloudCover:i(.5),uCloudSharp:i(.3),uSunDir:t(),uSunColor:e(),uSunGlow:i(1),uMoon:i(0),uStars:i(0),uFogColor:e(),uFogDensity:i(.03),uFogStart:i(6),uFogHeight:i(.1),uMist:i(1),uAmbSky:e(),uAmbGround:e(),uKeyColor:e(),uKeyStrength:i(.4),uRimColor:e(),uBark:e(),uLeaf:e(),uGround:e(),uStone:e(),uBeamDir:t(),uBeamColor:e(),uBeamStrength:i(1),uBeams:{value:Nl.map(([r,s,o,a])=>new Ct(r,s,o,a))},uHoloPos:t(0,3,0),uHoloColor:{value:new st(.85,1,.95)},uHoloLight:i(.5),uNight:i(0)}}const Xn=`
uniform float uTime;
uniform sampler2D uNoise;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform float uSunGlow;
uniform vec3 uFogColor; uniform float uFogDensity; uniform float uFogStart; uniform float uFogHeight;
uniform vec3 uAmbSky; uniform vec3 uAmbGround; uniform vec3 uKeyColor; uniform float uKeyStrength; uniform vec3 uRimColor;
uniform vec3 uBeamDir; uniform vec3 uBeamColor; uniform float uBeamStrength; uniform vec4 uBeams[8];
uniform vec3 uHoloPos; uniform vec3 uHoloColor; uniform float uHoloLight;
uniform float uNight;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float hash13(vec3 p3) { p3 = fract(p3 * 0.1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }

// Height fog integrated along the view ray (denser near the ground), plus sun in-scatter.
float fogAmount(vec3 wp) {
  vec3 d = wp - cameraPosition;
  float L = max(length(d) - uFogStart, 0.0);
  float yc = max(cameraPosition.y, 0.0), yp = max(wp.y, 0.0);
  float dy = yp - yc;
  float b = uFogHeight;
  float k = abs(dy) > 0.05 ? (exp(-b * yc) - exp(-b * yp)) / (b * dy) : exp(-b * yc);
  k = max(k, 0.22);
  return 1.0 - exp(-uFogDensity * L * k);
}
vec3 fogColorAt(vec3 wp) {
  vec3 v = normalize(wp - cameraPosition);
  float s = pow(max(dot(v, uSunDir), 0.0), 5.0);
  return uFogColor + uSunColor * s * 0.3 * uSunGlow;
}
vec3 applyFog(vec3 col, vec3 wp) { return mix(col, fogColorAt(wp), fogAmount(wp)); }

// Light shafts: each beam is a soft cylinder through its ground point along uBeamDir.
float beamField(vec3 p) {
  float acc = 0.0;
  for (int i = 0; i < 8; i++) {
    vec4 b = uBeams[i];
    if (b.w <= 0.0) continue;
    vec3 rel = p - vec3(b.x, 0.0, b.y);
    float t = dot(rel, uBeamDir);
    vec3 perp = rel - t * uBeamDir;
    float r = b.z * mix(1.0, 0.62, clamp(t / 34.0, 0.0, 1.0));
    acc += b.w * exp(-dot(perp, perp) / (r * r) * 2.2) * smoothstep(-0.8, 0.3, t);
  }
  return acc * uBeamStrength;
}

vec3 holoLight(vec3 p, vec3 n) {
  vec3 l = uHoloPos - p;
  float d2 = dot(l, l);
  l *= inversesqrt(d2);
  float ndl = max(dot(n, l) * 0.7 + 0.3, 0.0);
  return uHoloColor * (uHoloLight * ndl / (1.0 + d2 * 0.16));
}

// Shared bark/stone style lighting (no shadow maps: hemi ambient + soft key + beams + rim + AO).
vec3 shadeSurface(vec3 alb, vec3 N, vec3 V, vec3 wp, float ao, float rimAmt) {
  float hemi = N.y * 0.5 + 0.5;
  vec3 amb = mix(uAmbGround, uAmbSky, hemi);
  float wrap = max(dot(N, uBeamDir) * 0.5 + 0.5, 0.0);
  vec3 key = uKeyColor * (wrap * wrap * uKeyStrength * 0.32);
  float bl = beamField(wp);
  vec3 beam = uBeamColor * (bl * max(dot(N, uBeamDir) * 0.8 + 0.2, 0.0) * 1.7);
  float fres = pow(1.0 - max(dot(N, V), 0.0), 4.0);
  vec3 rim = uRimColor * (fres * rimAmt * clamp(N.y * 0.6 + 0.5, 0.0, 1.0));
  vec3 col = alb * (amb + key) * ao + alb * beam * mix(0.6, 1.0, ao) + rim * ao;
  col += alb * holoLight(wp, N) * mix(0.5, 1.0, ao);
  return col;
}
`,qM=[{skyTop:"#5b6fa8",skyHorizon:"#f6bfae",skyGain:1.7,cloudLit:"#ffd8cb",cloudShadow:"#7b7aa2",cloudCover:.56,cloudSharp:.3,sunDir:[-.38,.09,-.92],sunColor:"#ffbf9c",sunGlow:1.15,moon:0,stars:.05,fogColor:"#79717f",fogDensity:.0165,fogStart:16,fogHeight:.13,mist:.5,ambSky:"#4b5068",ambGround:"#251e20",keyColor:"#ffd0b8",keyStrength:.55,rim:"#e9c2bc",bark:"#4a3f3a",leaf:"#232920",ground:"#262019",stone:"#433b36",beamDir:[-.66,.6,-.45],beamColor:"#ffdcc8",beamStrength:1,holoLight:.55,night:.12,grade:{exposure:.92,contrast:1.2,saturation:.9,lift:[.01,.004,.02],gain:[1.03,.99,1],bloom:.8,threshold:.75,vignette:.62,grad:.55}},{skyTop:"#4a77bb",skyHorizon:"#d5e4f0",skyGain:1.8,cloudLit:"#ffffff",cloudShadow:"#8f9fbc",cloudCover:.56,cloudSharp:.26,sunDir:[-.5,.42,-.75],sunColor:"#fff1dc",sunGlow:.8,moon:0,stars:0,fogColor:"#7d7f80",fogDensity:.0135,fogStart:16,fogHeight:.12,mist:.38,ambSky:"#56627a",ambGround:"#2a241d",keyColor:"#fff0dc",keyStrength:.65,rim:"#dfe8f0",bark:"#4f453c",leaf:"#232a1c",ground:"#29231c",stone:"#463e37",beamDir:[-.52,.76,-.38],beamColor:"#fff4e4",beamStrength:1,holoLight:.45,night:0,grade:{exposure:.92,contrast:1.2,saturation:.95,lift:[.004,.006,.012],gain:[1,1,1],bloom:.7,threshold:.8,vignette:.58,grad:.55}},{skyTop:"#7f98b4",skyHorizon:"#f2e6d0",skyGain:1.75,cloudLit:"#fffaf0",cloudShadow:"#b4afa4",cloudCover:.68,cloudSharp:.4,sunDir:[-.18,.92,-.35],sunColor:"#fff3df",sunGlow:.7,moon:0,stars:0,fogColor:"#857b6b",fogDensity:.01425,fogStart:16,fogHeight:.11,mist:.32,ambSky:"#686457",ambGround:"#2e271e",keyColor:"#fff2dc",keyStrength:.7,rim:"#f6ecd8",bark:"#524638",leaf:"#262b1b",ground:"#2d251c",stone:"#4b4239",beamDir:[-.24,.94,-.24],beamColor:"#fff6e6",beamStrength:.75,holoLight:.4,night:0,grade:{exposure:.92,contrast:1.2,saturation:.85,lift:[.014,.01,.003],gain:[1.03,1,.95],bloom:.65,threshold:.8,vignette:.52,grad:.5}},{skyTop:"#3f5180",skyHorizon:"#ffb36b",skyGain:1.6,cloudLit:"#ffcb8a",cloudShadow:"#6e566e",cloudCover:.55,cloudSharp:.28,sunDir:[.58,.08,-.81],sunColor:"#ffab5a",sunGlow:1.25,moon:0,stars:0,fogColor:"#7b5f52",fogDensity:.022,fogStart:9,fogHeight:.12,mist:.65,ambSky:"#45405a",ambGround:"#261a15",keyColor:"#ffb874",keyStrength:.6,rim:"#ffc58f",bark:"#4c3c32",leaf:"#252418",ground:"#271d17",stone:"#443830",beamDir:[.62,.62,-.48],beamColor:"#ffc690",beamStrength:1,holoLight:.65,night:.35,grade:{exposure:1,contrast:1.1,saturation:.72,lift:[.014,.006,.012],gain:[1.04,.99,.93],bloom:.9,threshold:.7,vignette:.64,grad:.55}},{skyTop:"#0e1a3a",skyHorizon:"#2f4470",skyGain:1.15,cloudLit:"#61759f",cloudShadow:"#141c33",cloudCover:.5,cloudSharp:.3,sunDir:[-.24,.27,-.93],sunColor:"#aac4ff",sunGlow:.8,moon:1,stars:.55,fogColor:"#222f4a",fogDensity:.022,fogStart:9,fogHeight:.12,mist:.6,ambSky:"#1c2847",ambGround:"#0d1018",keyColor:"#9fb8ff",keyStrength:.45,rim:"#7c96cf",bark:"#3e3e47",leaf:"#141a20",ground:"#1b1c21",stone:"#3c3e48",beamDir:[-.42,.82,-.4],beamColor:"#b6c9ff",beamStrength:.5,holoLight:1,night:1,grade:{exposure:.98,contrast:1.1,saturation:.62,lift:[.004,.011,.032],gain:[.97,1,1.02],bloom:1,threshold:.6,vignette:.7,grad:.45}},{skyTop:"#050a18",skyHorizon:"#16233d",skyGain:1.1,cloudLit:"#6f81a8",cloudShadow:"#0a1022",cloudCover:.36,cloudSharp:.22,sunDir:[.12,.3,-.95],sunColor:"#d2deff",sunGlow:1.1,moon:1,stars:1.6,fogColor:"#141d31",fogDensity:.02,fogStart:9,fogHeight:.12,mist:.5,ambSky:"#121a30",ambGround:"#080a10",keyColor:"#c4d4ff",keyStrength:.45,rim:"#93abdc",bark:"#3a3a42",leaf:"#11161c",ground:"#17181c",stone:"#373943",beamDir:[.2,.9,-.38],beamColor:"#cbd8ff",beamStrength:.6,holoLight:1.15,night:.75,grade:{exposure:1,contrast:1.12,saturation:.6,lift:[.004,.009,.03],gain:[.96,.99,1.02],bloom:1.05,threshold:.55,vignette:.74,grad:.45}}],ff=["skyTop","skyHorizon","cloudLit","cloudShadow","sunColor","fogColor","ambSky","ambGround","keyColor","rim","bark","leaf","ground","stone","beamColor"],df=["skyGain","cloudCover","cloudSharp","sunGlow","moon","stars","fogDensity","fogStart","fogHeight","mist","keyStrength","beamStrength","holoLight","night"],pf=["sunDir","beamDir"],mf=["exposure","contrast","saturation","bloom","threshold","vignette","grad"],gf=["lift","gain"],_l=qM.map(n=>{const e={grade:{}};for(const t of ff)e[t]=new st(n[t]);for(const t of df)e[t]=n[t];for(const t of pf)e[t]=new O(...n[t]).normalize();for(const t of mf)e.grade[t]=n.grade[t];for(const t of gf)e.grade[t]=new O(...n.grade[t]);return e});function $M(){const n={grade:{}};for(const e of ff)n[e]=new st;for(const e of df)n[e]=0;for(const e of pf)n[e]=new O;for(const e of mf)n.grade[e]=0;for(const e of gf)n.grade[e]=new O;return n}function Qd(n,e){const t=_l.length,i=(e%t+t)%t,r=Math.floor(i),s=(r+1)%t,o=i-r,a=_l[r],l=_l[s];for(const c of ff)n[c].copy(a[c]).lerp(l[c],o);for(const c of df)n[c]=a[c]+(l[c]-a[c])*o;for(const c of pf)n[c].copy(a[c]).lerp(l[c],o).normalize();for(const c of mf)n.grade[c]=a.grade[c]+(l.grade[c]-a.grade[c])*o;for(const c of gf)n.grade[c].copy(a.grade[c]).lerp(l.grade[c],o);return n}function YM(n){const e=new jl(1,64,32),t=new xt({uniforms:n,vertexShader:`
      varying vec3 vDir;
      void main() {
        vDir = position;
        vec4 wp = modelMatrix * vec4(position, 1.0);
        gl_Position = projectionMatrix * viewMatrix * wp;
        gl_Position.z = gl_Position.w * 0.99999;
      }`,fragmentShader:`
      ${Xn}
      uniform vec3 uSkyTop; uniform vec3 uSkyHorizon; uniform float uSkyGain;
      uniform vec3 uCloudLit; uniform vec3 uCloudShadow; uniform float uCloudCover; uniform float uCloudSharp;
      uniform float uMoon; uniform float uStars;
      varying vec3 vDir;

      float cloudDensity(vec2 uv) {
        float a = texture2D(uNoise, uv * vec2(0.55, 1.0)).r;
        float b = texture2D(uNoise, uv * 2.3 + vec2(0.31, 0.77) + uTime * 0.0011).g;
        float c = texture2D(uNoise, uv * 5.1 + vec2(0.7, 0.2) - uTime * 0.0017).b;
        return a * 0.68 + b * 0.24 + c * 0.12;
      }

      void main() {
        vec3 dir = normalize(vDir);
        float y = dir.y;
        float yh = max(y, 0.0);
        vec3 col = mix(uSkyHorizon, uSkyTop, smoothstep(-0.03, 0.2, y) * 0.88 + pow(yh, 0.8) * 0.12) * uSkyGain;

        float sd = max(dot(dir, uSunDir), 0.0);
        // sun: broad warm glow; moon: a tighter cold halo so nights stay dark around it
        float wide = pow(sd, 3.0) * 0.22 * (1.0 - uMoon * 0.85);
        float mid = pow(sd, 18.0) * 0.45 * (1.0 - uMoon * 0.55);
        float core = pow(sd, 300.0) * 1.2 * (1.0 - uMoon) + pow(sd, 90.0) * 0.5 * uMoon;
        col += uSunColor * (wide + mid + core) * uSunGlow;

        // cloud deck
        if (y > -0.03) {
          vec2 cp = dir.xz / (y + 0.085);
          vec2 uv = cp * 0.055 + vec2(uTime * 0.0021, uTime * 0.0006);
          float d = cloudDensity(uv);
          float lo = 1.0 - uCloudCover;
          float cov = smoothstep(lo, lo + uCloudSharp, d);
          vec2 sunStep = normalize(uSunDir.xz + vec2(1e-4)) * 0.018;
          float d2 = cloudDensity(uv + sunStep);
          float lit = clamp(0.55 + (d - d2) * 7.0, 0.0, 1.0);
          float thick = smoothstep(lo, lo + uCloudSharp * 2.5, d);
          vec3 cc = mix(uCloudLit, uCloudShadow, thick * 0.75) * mix(0.75, 1.15, lit);
          cc += uSunColor * pow(sd, 6.0) * 0.55 * (1.0 - thick);
          cc *= uSkyGain;
          float fade = smoothstep(-0.03, 0.16, y);
          col = mix(col, cc, cov * fade);
        }

        // stars (night only)
        if (uStars > 0.01 && y > 0.0) {
          vec3 sp = dir * 260.0;
          vec3 cell = floor(sp);
          float h = hash13(cell);
          if (h > 0.985) {
            vec3 pt = cell + vec3(hash13(cell + 1.7), hash13(cell + 4.1), hash13(cell + 9.3));
            float d = length(sp - pt);
            float tw = 0.6 + 0.4 * sin(uTime * (1.0 + h * 3.0) + h * 40.0);
            col += vec3(0.85, 0.9, 1.0) * (1.0 - smoothstep(0.0, 0.42, d)) * tw * uStars * smoothstep(0.0, 0.25, y) * (h - 0.985) * 90.0;
          }
        }

        // moon disc with a soft halo
        if (uMoon > 0.01) {
          float md = acos(clamp(dot(dir, uSunDir), -1.0, 1.0));
          float disc = (1.0 - smoothstep(0.0115, 0.0135, md));
          float crater = texture2D(uNoise, (dir.xy - uSunDir.xy) * 9.0 + 0.5).r;
          col = mix(col, uSunColor * (2.4 - crater * 0.7), disc * uMoon);
          col += uSunColor * exp(-md * 26.0) * 0.35 * uMoon;
        }

        // below the horizon the sky dissolves into the fog colour
        col = mix(col, uFogColor, (1.0 - smoothstep(-0.05, 0.07, y)));
        col = mix(col, uFogColor, exp(-max(y, 0.0) * 26.0) * 0.5);
        gl_FragColor = vec4(col, 1.0);
      }`,side:Kt,depthWrite:!1,depthTest:!0}),i=new Gt(e,t);return i.name="sky",i.scale.setScalar(600),i.frustumCulled=!1,i.renderOrder=100,{mesh:i,update(r){i.position.copy(r.position)},dispose(){e.dispose(),t.dispose()}}}function Ka(n,e){const t=Math.sin(n*127.1+e*311.7)*43758.5453;return t-Math.floor(t)}function KM(n,e){const t=Math.floor(n),i=Math.floor(e),r=n-t,s=e-i,o=r*r*(3-2*r),a=s*s*(3-2*s),l=Ka(t,i),c=Ka(t+1,i),u=Ka(t,i+1),h=Ka(t+1,i+1);return l+(c-l)*o+(u-l)*a+(l-c-u+h)*o*a}function e0(n,e){let t=0,i=.5;for(let r=0;r<4;r++)t+=KM(n,e)*i,n*=2.03,e*=2.03,i*=.5;return t/.9375}function bm(n,e){const t=Math.hypot(n,e),i=bh(En.rOuter+2.4,En.rOuter+7,t);let r=(e0(n*.09+3.1,e*.09-1.7)-.5)*.9*i;return r+=bh(45,170,t)*8*(.55+.45*e0(n*.015,e*.015)),r-.04}function jM(n,e){const t=e.groundRadial,i=[0];for(;i[i.length-1]<300;)i.push(i[i.length-1]*1.07+.22);const r=[],s=[];for(let h=0;h<i.length;h++)for(let f=0;f<=t;f++){const d=f/t*Math.PI*2,v=Math.cos(d)*i[h],g=Math.sin(d)*i[h];r.push(v,bm(v,g),g)}const o=t+1;for(let h=0;h<i.length-1;h++)for(let f=0;f<t;f++){const d=h*o+f,v=d+1,g=d+o,p=g+1;s.push(d,v,g,v,p,g)}const a=new Et;a.setAttribute("position",new nt(r,3)),a.setIndex(r.length/3>65535?new ql(s,1):new Xl(s,1)),a.computeVertexNormals();const l=[];for(const h of vl)l.push(new O(-h.w,h.z,h.r0*1.9),new O(h.w,h.z,h.r0*1.9));for(const[h,f]of Mm.slice(0,6))l.push(new O(h,f,1.6));for(;l.length<20;)l.push(new O(9999,9999,.01));const c=new xt({uniforms:{...n,uFeet:{value:l.slice(0,20)},uKund:{value:new we(En.rOuter,En.rimY)}},vertexShader:`
      varying vec3 vWorld; varying vec3 vNormal;
      void main() {
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vWorld = wp.xyz; vNormal = normal;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,fragmentShader:`
      ${Xn}
      uniform vec3 uGround; uniform vec3 uStone; uniform vec3 uFeet[20]; uniform vec2 uKund;
      varying vec3 vWorld; varying vec3 vNormal;
      void main() {
        vec2 xz = vWorld.xz;
        float r = length(xz);
        float n1 = texture2D(uNoise, xz * 0.021).r;
        float n2 = texture2D(uNoise, xz * 0.13).g;
        float cells = texture2D(uNoise, xz * 0.31).a;
        vec3 alb = uGround * (0.62 + 0.5 * n1) * (0.85 + 0.3 * n2);
        // moss and leaf litter
        alb = mix(alb, uGround * vec3(0.78, 0.95, 0.7), smoothstep(0.55, 0.75, n1) * 0.5);
        alb *= 0.85 + 0.3 * (1.0 - smoothstep(0.0, 0.15, cells));

        // stone plaza ring around the kund (laterite flags with joints)
        float plazaIn = uKund.x + 0.02;
        // the outer edge of the paving is broken and swallowed by earth, not a clean ring
        float plazaOut = uKund.x + 2.1 + (texture2D(uNoise, xz * 0.05).r - 0.5) * 2.2;
        float plaza = (1.0 - smoothstep(plazaOut - 0.6, plazaOut + 0.4, r)) * step(plazaIn, r);
        plaza *= step(0.18, texture2D(uNoise, xz * 0.21 + 0.4).r + plaza * 0.25); // missing flags near the edge
        float ang = atan(xz.y, xz.x);
        float ringIdx = floor((r - plazaIn) / 0.78);
        float jointA = abs(fract(ang * (40.0 + ringIdx * 6.0) / 6.2831 + ringIdx * 0.37) - 0.5);
        float jointR = abs(fract((r - plazaIn) / 0.78) - 0.5);
        float joints = smoothstep(0.47, 0.5, max(jointA, jointR));
        vec3 flag = uStone * 0.62 * (0.8 + 0.35 * n2) * (1.0 - joints * 0.55);
        flag *= mix(1.0, 0.65, smoothstep(0.55, 0.85, n1)); // worn, dark patches
        alb = mix(alb, flag, plaza * (1.0 - smoothstep(0.62, 0.9, n2 * n1 * 1.6) * 0.6));

        // contact darkening at trunk feet and at the kund's foot
        float ao = 1.0;
        for (int i = 0; i < 20; i++) {
          vec3 f = uFeet[i];
          float d = length(xz - f.xy);
          ao *= mix(0.45, 1.0, smoothstep(f.z * 0.35, f.z * 1.6, d));
        }
        ao *= mix(0.5, 1.0, smoothstep(uKund.x, uKund.x + 0.9, r));
        vec3 N = normalize(vNormal + vec3(n2 - 0.5, 0.0, n1 - 0.5) * 0.25);
        vec3 V = normalize(cameraPosition - vWorld);
        vec3 col = shadeSurface(alb, N, V, vWorld, ao, 0.0);
        float far = smoothstep(70.0, 190.0, length(vWorld - cameraPosition));
        col = mix(applyFog(col, vWorld), fogColorAt(vWorld), far);
        gl_FragColor = vec4(col, 1.0);
      }`}),u=new Gt(a,c);return u.name="ground",u.frustumCulled=!1,{mesh:u,triangles:s.length/3,dispose(){a.dispose(),c.dispose()}}}function ZM(){const{rInner:n,rRim:e,rOuter:t,rimY:i,stepH:r}=En,s=(t-e)/2,o=.035,a=i-r,l=a-r;return[[0,0,n,0,0,.3,.3],[n,0,n,i-o,0,.35,.95],[n,i-o,n+o,i,1,.95,1,"bevel"],[n+o,i,e-o,i,1,1,1],[e-o,i,e,i-o,1,1,.95,"bevel"],[e,i-o,e,a,1,.95,.62],[e,a,e+s-o,a,2,.55,1],[e+s-o,a,e+s,a-o,2,1,.95,"bevel"],[e+s,a-o,e+s,l,2,.95,.62],[e+s,l,t-o,l,3,.55,1],[t-o,l,t,l-o,3,1,.95,"bevel"],[t,l-o,t,-.12,3,.95,.5]]}function JM(n){const e=n[2]-n[0],t=n[3]-n[1],i=Math.hypot(e,t);return[-t/i,e/i]}function QM(n){const e=ZM(),t=e.map(JM),i=[],r=[],s=[],o=[],a=[],l=[];let c=0,u=0;e.forEach((f,d)=>{let v=t[d],g=t[d];f[7]==="bevel"&&(v=t[d-1],g=t[d+1]);const p=Math.hypot(f[2]-f[0],f[3]-f[1]),m=c;for(let x=0;x<=n;x++){const _=x/n*Math.PI*2,y=Math.cos(_),C=Math.sin(_);for(let M=0;M<2;M++){const w=M?f[2]:f[0],P=M?f[3]:f[1],I=M?g:v;i.push(y*w,P,C*w),r.push(y*I[0],I[1],C*I[0]),s.push(x/n,u+(M?p:0)),o.push(M?f[6]:f[5]),a.push(f[4])}c+=2}for(let x=0;x<n;x++){const _=m+x*2,y=_+1,C=_+2,M=_+3;l.push(_,C,y,C,M,y)}u+=p});const h=new Et;return h.setAttribute("position",new nt(i,3)),h.setAttribute("normal",new nt(r,3)),h.setAttribute("uv",new nt(s,2)),h.setAttribute("aAO",new nt(o,1)),h.setAttribute("aCourse",new nt(a,1)),h.setIndex(l),h}function eb(n,e){const t=new Zn;t.name="kund";const i=QM(e.kundSegs),r=new xt({uniforms:{...n,uWaterY:{value:En.waterY},uRimR:{value:(En.rInner+En.rRim)/2},uRimY:{value:En.rimY}},vertexShader:`
      attribute float aAO; attribute float aCourse;
      varying vec3 vWorld; varying vec3 vNormal; varying vec2 vUv; varying float vAO; varying float vCourse;
      void main() {
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vWorld = wp.xyz; vNormal = normal; vUv = uv; vAO = aAO; vCourse = aCourse;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,fragmentShader:`
      ${Xn}
      uniform vec3 uStone; uniform float uWaterY; uniform float uRimR; uniform float uRimY;
      varying vec3 vWorld; varying vec3 vNormal; varying vec2 vUv; varying float vAO; varying float vCourse;
      void main() {
        float r = length(vWorld.xz);
        float blocks = 26.0 + vCourse * 7.0;
        float warp = texture2D(uNoise, vec2(vUv.x * 3.0, vCourse * 0.21)).r - 0.5;
        float bu = vUv.x * blocks + vCourse * 0.5 + warp * 0.9;
        float bid = floor(bu);
        float f = fract(bu);
        float arcLen = 6.2831 * r / blocks;
        float seamD = min(f, 1.0 - f) * arcLen;
        float seam = (1.0 - smoothstep(0.0, 0.022, seamD)) * (0.55 + 0.45 * hash12(vec2(bid, 3.0)));
        float tone = 0.86 + 0.28 * hash12(vec2(bid, vCourse * 7.0));
        float n1 = texture2D(uNoise, vec2(vUv.x * 18.0, vUv.y * 1.3)).g;
        float n2 = texture2D(uNoise, vec2(vUv.x * 5.0, vUv.y * 0.4) + 0.21).r;
        float pits = texture2D(uNoise, vec2(vUv.x * 40.0, vUv.y * 3.0)).a;
        vec3 alb = uStone * tone * (0.78 + 0.34 * n1) * (0.86 + 0.2 * (1.0 - smoothstep(0.0, 0.1, pits)));
        alb *= mix(1.0, 0.7, smoothstep(0.55, 0.8, n2)); // weathering stains
        alb *= 1.0 - seam * 0.45;
        // rain streaks down the vertical faces, moss and grime in the concave corners
        float vertical = 1.0 - abs(normalize(vNormal).y);
        float streaks = texture2D(uNoise, vec2(vUv.x * 60.0, vUv.y * 0.6)).g;
        alb *= 1.0 - vertical * smoothstep(0.45, 0.85, streaks) * 0.35;
        float grime = (1.0 - smoothstep(0.55, 0.95, vAO)) * (0.6 + 0.4 * n2);
        alb = mix(alb, alb * vec3(0.62, 0.72, 0.5), grime * 0.7);
        // wet, dark band at the water line on the inner wall
        float wet = (vCourse < 0.5) ? (1.0 - smoothstep(uWaterY - 0.02, uWaterY + 0.12, vWorld.y)) : 0.0;
        alb *= 1.0 - wet * 0.6;
        vec3 N = normalize(vNormal);
        vec3 V = normalize(cameraPosition - vWorld);
        float ao = vAO * (1.0 - seam * 0.3);
        vec3 col = shadeSurface(alb, N, V, vWorld, ao, 0.05);
        // diya glow pooled along the rim at night
        float dr = length(vec2(r - uRimR, vWorld.y - uRimY));
        col += alb * vec3(1.0, 0.62, 0.3) * uNight * 1.6 * exp(-dr * dr * 10.0);
        col = applyFog(col, vWorld);
        gl_FragColor = vec4(col, 1.0);
      }`}),s=new Gt(i,r);s.name="kund-stone",t.add(s);const o=new da(En.rInner+.01,e.kundSegs);o.rotateX(-Math.PI/2),o.translate(0,En.waterY,0);const a=new xt({uniforms:{...n,uHoloSpan:{value:new we(jr[1],jr[1]+Sm)}},vertexShader:`
      varying vec3 vWorld;
      void main() {
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vWorld = wp.xyz;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,fragmentShader:`
      ${Xn}
      uniform vec3 uSkyTop; uniform vec3 uSkyHorizon; uniform float uSkyGain; uniform vec2 uHoloSpan;
      varying vec3 vWorld;
      void main() {
        vec2 p = vWorld.xz;
        float r = length(p - uHoloPos.xz);
        vec3 V = normalize(cameraPosition - vWorld);
        float n1 = texture2D(uNoise, p * 0.23 + vec2(uTime * 0.011, 0.0)).g;
        float n2 = texture2D(uNoise, p * 0.41 - vec2(0.0, uTime * 0.014)).g;
        float ring = sin(r * 8.0 - uTime * 1.25) * exp(-r * 0.55);
        vec2 radial = (p - uHoloPos.xz) / max(r, 1e-3);
        vec3 N = normalize(vec3((n1 - 0.5) * 0.09 + radial.x * ring * 0.025, 1.0, (n2 - 0.5) * 0.09 + radial.y * ring * 0.025));
        vec3 R = reflect(-V, N);
        float fres = 0.02 + 0.98 * pow(1.0 - max(dot(N, V), 0.0), 5.0);
        vec3 sky = mix(uSkyHorizon, uSkyTop, pow(max(R.y, 0.0), 0.5)) * uSkyGain;
        // grazing reflections meet the haze beyond the grove (so by day the water reads as a pale
        // ellipse, like a still pool), broken by the dark crowns behind the kund; steep ones see sky
        vec3 haze = fogColorAt(vWorld + R * 40.0);
        float crowns = smoothstep(0.38, 0.62, texture2D(uNoise, vec2(atan(R.x, -R.z) * 1.9 + 0.13, 0.37)).r);
        vec3 env = mix(haze * mix(0.62, 0.22, crowns), sky * 0.4, smoothstep(0.12, 0.45, R.y));
        // reflection of the hologram column (reflected ray vs. the vertical axis through the anchor)
        vec2 o = p - uHoloPos.xz;
        float rr = max(dot(R.xz, R.xz), 1e-4);
        float t = max(-dot(o, R.xz) / rr, 0.0);
        float d = length(o + t * R.xz);
        float yAt = vWorld.y + t * R.y;
        float span = smoothstep(uHoloSpan.x - 0.4, uHoloSpan.x + 0.3, yAt) * (1.0 - smoothstep(uHoloSpan.y - 0.5, uHoloSpan.y + 0.4, yAt));
        float holo = exp(-d * d * 2.2) * span;
        vec3 col = vec3(0.004, 0.006, 0.007) + env * fres;
        col += uHoloColor * holo * 0.9 * fres * 2.2;
        col += uHoloColor * exp(-r * r * 0.35) * 0.06 * (0.7 + 0.3 * ring);
        // the machine's light pooled on the water right under it (~1.2 m): grounds the hologram
        float pool = exp(-r * r * 1.15) * (0.88 + 0.12 * ring);
        col += uHoloColor * pool * uHoloLight * 0.55;
        col += uBeamColor * beamField(vWorld) * 0.25 * fres;
        // light path: the hologram's glow smeared across the ripples towards the viewer
        vec3 toCam = cameraPosition - uHoloPos;
        vec3 side = normalize(vec3(toCam.z, 0.0, -toCam.x));
        float dPath = dot(vWorld - uHoloPos, side);
        float glint = smoothstep(0.5, 0.85, texture2D(uNoise, p * vec2(0.9, 2.6) + vec2(0.0, uTime * 0.02)).g);
        float path = exp(-dPath * dPath * 2.6) * smoothstep(-3.0, 1.5, dot(vWorld.xz - uHoloPos.xz, normalize(toCam.xz)));
        col += uHoloColor * path * (0.06 + 0.5 * glint) * (0.45 + uHoloLight * 0.4);
        col = applyFog(col, vWorld);
        gl_FragColor = vec4(col, 1.0);
      }`}),l=new Gt(o,a);l.name="kund-water",t.add(l);const c=14,u=new Float32Array(c*3),h=new Float32Array(c),f=(En.rInner+En.rRim)/2;for(let p=0;p<c;p++){const m=p/c*Math.PI*2+.11;u.set([Math.cos(m)*f,En.rimY+.07,Math.sin(m)*f],p*3),h[p]=p*1.37}const d=new Et;d.setAttribute("position",new kt(u,3)),d.setAttribute("aSeed",new kt(h,1));const v=new xt({uniforms:{uTime:n.uTime,uNight:n.uNight,uScale:{value:800}},vertexShader:`
      uniform float uTime; uniform float uNight; uniform float uScale;
      attribute float aSeed; varying float vFlick;
      void main() {
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        vFlick = 0.75 + 0.25 * sin(uTime * 9.0 + aSeed * 3.1) * sin(uTime * 5.3 + aSeed);
        gl_PointSize = uScale * 0.11 * vFlick / -mv.z * step(0.02, uNight);
        gl_Position = projectionMatrix * mv;
      }`,fragmentShader:`
      uniform float uNight; varying float vFlick;
      void main() {
        vec2 q = gl_PointCoord * 2.0 - 1.0;
        q.y *= 0.7;
        float d = length(q);
        float core = exp(-d * d * 9.0);
        float halo = exp(-d * d * 2.2) * 0.25;
        vec3 c = vec3(1.0, 0.72, 0.38) * (core * 3.0 + halo) * vFlick * uNight;
        gl_FragColor = vec4(c, 1.0);
      }`,transparent:!0,depthWrite:!1,blending:Zr}),g=new Yl(d,v);return g.name="kund-diyas",g.frustumCulled=!1,t.add(g),{group:t,triangles:i.index.count/3+e.kundSegs,setPixelScale(p){v.uniforms.uScale.value=p},dispose(){i.dispose(),r.dispose(),o.dispose(),a.dispose(),d.dispose(),v.dispose()}}}class tb{constructor(){this.pos=[],this.nor=[],this.uv=[],this.ao=[],this.misc=[],this.idx=[],this.count=0}build(){const e=new Et;return e.setAttribute("position",new nt(this.pos,3)),e.setAttribute("normal",new nt(this.nor,3)),e.setAttribute("uv",new nt(this.uv,2)),e.setAttribute("aAO",new nt(this.ao,1)),e.setAttribute("aMisc",new nt(this.misc,3)),e.setIndex(this.count>65535?new ql(this.idx,1):new Xl(this.idx,1)),e.computeBoundingSphere(),e}}function nb(n,e,t,i,r,s=new O){const o=1-r,a=o*o*o,l=3*o*o*r,c=3*o*r*r,u=r*r*r;return s.set(a*n.x+l*e.x+c*t.x+u*i.x,a*n.y+l*e.y+c*t.y+u*i.y,a*n.z+l*e.z+c*t.z+u*i.z)}const t0=new Hi,ja=new O,Qc=new O,n0=new O,Co=new O,Ro=new O;function tr(n,e,t,i={}){const r=i.radial??12,s=i.flute??.08,o=i.fluteN??5,a=i.twist??1.2,l=i.seed??0,c=i.sway??0,u=i.tint??1,h=i.groundAO??1,f=e.length-1;if(i.capEnd){e=e.slice(),t=t.slice();const M=e[f],w=new O().subVectors(M,e[f-1]).normalize(),P=t[f];for(let I=1;I<=4;I++){const S=I/4*Math.PI*.48;e.push(M.clone().addScaledVector(w,P*Math.sin(S))),t.push(P*Math.cos(S))}}const d=e.length,v=d-1,g=[],p=[],m=[];for(let M=0;M<d;M++){const w=e[Math.max(M-1,0)],P=e[Math.min(M+1,d-1)];g.push(new O().subVectors(P,w).normalize())}const x=Math.abs(g[0].y)<.9?new O(0,1,0):new O(1,0,0);p.push(new O().crossVectors(g[0],x).normalize()),m.push(new O().crossVectors(g[0],p[0]).normalize());for(let M=1;M<d;M++){const w=p[M-1].clone();ja.crossVectors(g[M-1],g[M]);const P=ja.length();if(P>1e-6){ja.multiplyScalar(1/P);const I=Math.acos(Bi.clamp(g[M-1].dot(g[M]),-1,1));t0.setFromAxisAngle(ja,I),w.applyQuaternion(t0)}p.push(w),m.push(new O().crossVectors(g[M],w).normalize())}const _=[0];for(let M=1;M<d;M++)_.push(_[M-1]+e[M].distanceTo(e[M-1]));const y=n.count;for(let M=0;M<d;M++){const w=Math.min(M/f,1),P=e[M],I=t[M],S=Math.max(M-1,0),b=Math.min(M+1,d-1),N=(t[b]-t[S])/Math.max(_[b]-_[S],1e-4);for(let R=0;R<=r;R++){const H=R/r*Math.PI*2,T=H+a*w,k=2*o+1,Z=Math.sin(o*T+l)*.62+Math.sin(k*T+l*1.7+w*5)*.38,K=.62*o*Math.cos(o*T+l)+.38*k*Math.cos(k*T+l*1.7+w*5),pe=I*(1+s*Z),ce=I*s*K,W=Math.cos(H),re=Math.sin(H);Qc.copy(p[M]).multiplyScalar(W).addScaledVector(m[M],re),n0.copy(p[M]).multiplyScalar(-re).addScaledVector(m[M],W),Ro.copy(P).addScaledVector(Qc,pe),Co.copy(Qc).multiplyScalar(pe).addScaledVector(n0,-ce).normalize(),Co.addScaledVector(g[M],-N).normalize(),n.pos.push(Ro.x,Ro.y,Ro.z),n.nor.push(Co.x,Co.y,Co.z),n.uv.push(R/r,_[M]*.22);const Ae=.72+.28*(Z*.5+.5),ee=Bi.lerp(1,.28+.72*Bi.smoothstep(Ro.y,-.4,3.2),h);n.ao.push(Ae*ee),n.misc.push(c*Math.pow(w,1.6),l%1,u)}}const C=r+1;for(let M=0;M<v;M++)for(let w=0;w<r;w++){const P=y+M*C+w,I=P+1,S=P+C,b=S+1;n.idx.push(P,I,S,I,b,S)}n.count+=d*C}function Zs(n,e,t,i,r,s=0,o=Math.random){const a=[],l=2+o()*3,c=2+o()*3,u=o()*6.28,h=o()*6.28;for(let f=0;f<=r;f++){const d=f/r,v=nb(n,e,t,i,d);if(s>0){const g=Math.sin(Math.PI*d)*s;v.x+=Math.sin(l*d*3.1+u)*g,v.z+=Math.sin(c*d*3.1+h)*g}a.push(v)}return a}const i0=new O(0,1,0);function Za(n,e,t,i=.86,r=.3){const s=[];for(let o=0;o<=n;o++){const a=o/n;let l=t+(e-t)*Math.pow(1-a,1.5);l*=1+.85*Math.exp(-a*15),a>i&&(l*=Bi.lerp(1,r,(a-i)/(1-i))),s.push(l)}return s}function eu(n,e,t,i){const r=new O(t.x-e.x,0,t.z-e.z),s=r.length();r.normalize();const o=t.y-e.y,a=e.clone(),l=e.clone().addScaledVector(i0,o*Le(n,.4,.5)).addScaledVector(r,s*Le(n,0,.08)),c=e.clone().addScaledVector(i0,o*Le(n,.8,.86)).addScaledVector(r,s*Le(n,.58,.7));Le(n,1.1,1.2);const u=t.clone();return Zs(a,l,c,u,i,Le(n,.15,.35),n)}function ib(n){const e=Mr(n.seed),t=new O(n.x,-.6,n.z),i=new O(n.x+n.lean,n.h*.42,n.z+Le(e,-.3,.3)),r=Zs(t,new O(n.x,n.h*.2,n.z),new O(n.x+n.lean*.6,n.h*.38,n.z),i,14,.12,e),s=[],o=[],a=5+Math.floor(e()*2);for(let l=0;l<a;l++){const c=l/a*Math.PI*2+Le(e,-.4,.4),u=n.spread*Le(e,.6,1),h=new O(i.x+Math.cos(c)*u+n.lean*.8,n.h*Le(e,.82,1.02),i.z+Math.sin(c)*u*.7),f=i.clone().lerp(h,.35).add(new O(0,.5,0)),d=i.clone().lerp(h,.75).add(new O(0,.35,0));s.push(Zs(i,f,d,h,10,.1,e)),o.push(h),o.push(i.clone().lerp(h,.6).add(new O(0,.45,0)))}return o.push(i.clone().add(new O(n.lean*.5,n.h*.42,0))),{trunk:r,branches:s,crowns:o}}function rb(n,e){const t=Mr(1729),i=new tb,r=[],s=jr[0],o=e.legSegs,a=e.legRadial,l=[];vl.forEach((p,m)=>{const x=p.h*Le(t,.95,1.05),_=p.z+Le(t,-.6,.6);let y=null,C=null;for(const M of[-1,1]){const w=new O(M*p.w*Le(t,.96,1.04),-1.3,p.z+Le(t,-.7,.7)),P=Le(t,-.25,.25);y=y||new O(P,x,_);const I=eu(t,w,y,o),S=Za(o,p.r0*Le(t,.92,1.08),p.r1,.86,.45);if(tr(i,I,S,{radial:a,flute:.11,fluteN:4+m%3,twist:Le(t,.8,2.2)*M,seed:t()*10,tint:Le(t,.85,1.12),capEnd:!0}),l.push({pts:I,radii:S,row:m,side:M}),p.diag&&vl[m+1]){const b=vl[m+1],N=(p.z+b.z)/2+Le(t,-.8,.8);Le(t,.4,1.4);const R=(x+b.h)*.5*Le(t,.97,1.05);C=C||new O(0,R,N);const H=eu(t,w.clone().add(new O(-M*.25,0,-.35)),C,Math.round(o*.85)),T=Za(H.length-1,p.r0*.72,p.r1*.85,.86,.45);tr(i,H,T,{radial:Math.max(6,a-4),flute:.12,fluteN:3,twist:Le(t,-1.5,1.5),seed:t()*10,tint:Le(t,.85,1.1),capEnd:!0}),l.push({pts:H,radii:T,row:m,side:M,diag:!0})}for(let b=0;b<4&&m<3;b++){const N=Math.atan2(0,M)+Le(t,-1.6,1.6),R=new O(Math.cos(N),0,Math.sin(N)),H=w.clone().add(new O(0,Le(t,2.2,3.4),0)).addScaledVector(R,p.r0*.4),T=w.clone().addScaledVector(R,Le(t,2.2,3.6)).add(new O(0,.2,0)),k=H.clone().addScaledVector(R,.8).add(new O(0,-.6,0)),Z=T.clone().add(new O(0,1.1,0)).addScaledVector(R,-.7),K=Zs(H,k,Z,T,16,.08,t),pe=t()*10;if(m>=e.buttressRows)continue;const ce=K.map((W,re)=>Bi.lerp(p.r0*.38,p.r0*.14,re/16));tr(i,K,ce,{radial:Math.max(6,a-6),flute:.08,fluteN:3,twist:.4,seed:pe,tint:.95})}}});{const p=Rs.h;let m=null;for(const x of[-1,1]){const _=new O(x*Rs.w,-1.3,Rs.z+Le(t,-.4,.4)),y=Le(t,-.2,.2);m=m||new O(y,p,Rs.z);const C=eu(t,_,m,o);tr(i,C,Za(o,Rs.r0,Rs.r1,.86,.45),{radial:a,flute:.12,fluteN:5,twist:1.6*x,seed:t()*10,tint:.95,capEnd:!0})}}for(const p of l){if(p.row>0)continue;const m=p.pts.length-1;for(let x=Math.floor(m*.5);x<=Math.floor(m*.74);x+=Math.max(2,Math.floor(m/16)))Math.abs(p.pts[x].x)<3.8||r.push({p:p.pts[x].clone(),size:1+x/m*.5,row:p.row})}Mm.forEach(([p,m],x)=>{const _=Le(t,12,17),y=new O(p,-1.2,m),C=-Math.sign(p)*Le(t,4.5,8.5),M=new O(p+Le(t,-.8,.8),_*.38,m),w=new O(p+C*.35,_*.82,m+Le(t,-1.5,1.5)),P=new O(p+C,_*1.02,m+Le(t,-3,3)),I=Math.round(o*.5),S=Zs(y,M,w,P,I,.3,t),b=Za(I,Le(t,.85,1.3),.26,.8,.25),N=Le(t,.9,1.1);if(!(x>=e.sideTrunks)&&(tr(i,S,b,{radial:Math.max(6,a-4),flute:.12,fluteN:4,twist:1,seed:x*1.3,tint:N}),Math.abs(p)>14))for(let R=Math.floor(I*.6);R<=I;R+=5)r.push({p:S[R].clone(),size:1.1,row:9})});const c=Mr(4242);let u=0;const h=l.filter(p=>p.row<=4);for(let p=0;u<e.roots&&p<e.roots*6;p++){const m=h[Math.floor(c()*h.length)],x=m.pts.length-1,_=Math.floor(x*Le(c,.32,.86)),y=m.pts[_];if(Math.abs(y.x-s)<2.7||y.y<3.5)continue;const C=2+Math.floor(c()*4);for(let M=0;M<C&&u<e.roots;M++){const w=y.clone().add(new O(Le(c,-.35,.35),-m.radii[_]*.6,Le(c,-.35,.35)));if(Math.abs(w.x-s)<2.5)continue;const P=c()<.16,I=P?w.y+.6:w.y*Le(c,.3,.8),S=new O(Le(c,-.5,.5),0,Le(c,-.5,.5)),b=w.clone().add(new O(S.x,-I,S.z)),N=w.clone().add(new O(S.x*.1+Le(c,-.2,.2),-I*.33,S.z*.1)),R=w.clone().add(new O(S.x*.7,-I*.7,S.z*.7)),H=e.rootSegs,T=Zs(w,N,R,b,H,.05,c),k=P?Le(c,.08,.16):Le(c,.02,.055),Z=T.map((K,pe)=>{const ce=pe/H;return P?k*(.55+.45*ce)*(1+1.2*Math.exp(-(1-ce)*12)):k*(1-.75*ce)});tr(i,T,Z,{radial:P?e.rootRadial+2:e.rootRadial,flute:P?.1:0,fluteN:3,twist:.5,seed:c()*10,sway:P?0:1,tint:Le(c,.9,1.15),groundAO:P?1:.6}),u++}}const f=[];GM.slice(0,e.neems).forEach(p=>{const m=ib(p),x=m.trunk.map((_,y)=>Bi.lerp(.32,.17,y/(m.trunk.length-1))*(1+.6*Math.exp(-y*.8)));tr(i,m.trunk,x,{radial:8,flute:.06,fluteN:3,twist:.6,seed:p.seed,tint:.8});for(const _ of m.branches){const y=_.map((C,M)=>Bi.lerp(.13,.03,M/(_.length-1)));tr(i,_,y,{radial:6,flute:0,twist:0,seed:p.seed,tint:.8,groundAO:0})}f.push({tree:p,crowns:m.crowns})});const d=i.build(),v=new xt({uniforms:n,vertexShader:`
      uniform float uTime;
      attribute float aAO;
      attribute vec3 aMisc;
      varying vec3 vWorld; varying vec3 vNormal; varying vec2 vUv; varying float vAO; varying float vTint;
      void main() {
        vec3 p = position;
        float sw = aMisc.x;
        if (sw > 0.0) {
          float ph = uTime * 0.5 + aMisc.y * 6.2831;
          p.x += sin(ph) * 0.07 * sw;
          p.z += cos(ph * 0.83) * 0.06 * sw;
        }
        vec4 wp = modelMatrix * vec4(p, 1.0);
        vWorld = wp.xyz;
        vNormal = normalize(mat3(modelMatrix) * normal);
        vUv = uv; vAO = aAO; vTint = aMisc.z;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,fragmentShader:`
      ${Xn}
      uniform vec3 uBark;
      varying vec3 vWorld; varying vec3 vNormal; varying vec2 vUv; varying float vAO; varying float vTint;
      void main() {
        vec3 N = normalize(vNormal);
        vec3 V = normalize(cameraPosition - vWorld);
        float streak = texture2D(uNoise, vec2(vUv.x * 2.0, vUv.y * 0.12)).g;
        float blotch = texture2D(uNoise, vec2(vUv.x * 0.5, vUv.y * 0.05) + 0.37).r;
        float pores = texture2D(uNoise, vec2(vUv.x * 4.0, vUv.y * 0.9)).a;
        // bark relief: screen-space bump from the fissure pattern (shows on the near trunks)
        float hgt = streak * 0.7 + pores * 0.3;
        vec3 dpx = dFdx(vWorld), dpy = dFdy(vWorld);
        float dhx = dFdx(hgt), dhy = dFdy(hgt);
        vec3 r1 = cross(dpy, N), r2 = cross(N, dpx);
        float det = dot(dpx, r1);
        vec3 grad = (sign(det) * (dhx * r1 + dhy * r2)) * 0.06;
        N = normalize(abs(det) * N - grad);
        vec3 alb = uBark * vTint * (0.72 + 0.4 * streak) * (0.82 + 0.36 * blotch) * (0.9 + 0.12 * pores);
        // lichen-pale patches higher up the limbs
        alb = mix(alb, alb * vec3(1.25, 1.22, 1.12), smoothstep(0.62, 0.8, blotch) * smoothstep(2.0, 8.0, vWorld.y) * 0.6);
        float ao = vAO * (0.88 + 0.12 * streak);
        vec3 col = shadeSurface(alb, N, V, vWorld, ao, 0.16);
        col = applyFog(col, vWorld);
        gl_FragColor = vec4(col, 1.0);
      }`}),g=new Gt(d,v);return g.name="banyan",g.frustumCulled=!1,{mesh:g,leafAnchors:r,neemCrowns:f,triangles:d.index.count/3,dispose(){d.dispose(),v.dispose()}}}function sb(n,e,t){let i=Mr(99);const r=g=>{i=Mr(g)},s=[],o=(g,p,m,x,_,y)=>s.push([g,p,m,x,i()*6.283,i()*37,_,y]);for(const g of t.leafAnchors){if(i()>e.canopyKeep||g.p.y<10.5)continue;const p=4+Math.floor(i()*4);for(let m=0;m<p;m++)o(g.p.x+Le(i,-1.8,1.8),g.p.y+Le(i,-.3,1.8),g.p.z+Le(i,-1.6,1.6),Le(i,1.8,3.2)*g.size,Le(i,.65,1.1),0)}r(199);for(let g=0;g<e.ceiling;g++){const m=(i()<.5?-1:1)*Le(i,6.5,20),x=Le(i,-8,8),_=Le(i,9.5,15)+(Math.abs(m)-6.5)*.2+Math.max(0,x)*.35;o(m,_,x,Le(i,2,4.2),Le(i,.6,1),0)}r(299);for(const g of t.neemCrowns){const p=g.tree,m=p.x+p.lean*.9,x=p.h*.86,_=p.z,y=Math.round(30*e.neemDensity);for(let C=0;C<y;C++){const M=i()*6.283,w=Math.sqrt(i()),P=w*p.spread*.85,I=i(),S=x+(1-w*w)*.75-I*.55+Le(i,-.1,.1);o(m+Math.cos(M)*P,S,_+Math.sin(M)*P*.7,Le(i,1.5,2.5)*(1.1-w*.3),Le(i,.7,1.05),1)}for(const C of g.crowns)o(C.x+Le(i,-.4,.4),C.y+Le(i,-.2,.3),C.z+Le(i,-.4,.4),Le(i,.9,1.5),Le(i,.75,1.1),1)}r(399),VM.slice(0,e.shrubs).forEach(g=>{const p=Math.round(8+g.r*6);for(let m=0;m<p;m++){const x=i()*6.283,_=Math.sqrt(i()),y=_*g.r*.8,C=Math.sqrt(Math.max(0,1-_*_)),M=g.h*(.25+.75*C)*Le(i,.75,1);o(g.x+Math.cos(x)*y,M,g.z+Math.sin(x)*y*.8,Le(i,.6,1)*(.45+g.r*.45),Le(i,.65,1),1)}}),r(499);for(let g=0;g<e.treeline;g++){const p=Le(i,-150,150),m=Le(i,-95,-150)+Math.abs(p)*.25,x=Le(i,9,18);o(p,Le(i,2.5,6.5)+x*.15,m,x,Le(i,.7,1),1)}r(599);for(let g=0;g<e.grass;g++){const m=(i()<.5?-1:1)*Le(i,1.5,9.5),x=Le(i,5.4,8.8),_=Le(i,.5,1)*(1+Math.abs(m)*.05);o(m,_*.38-.05,x,_,Le(i,.5,.9),2)}const a=s.length,l=new Float32Array(a*3),c=new Float32Array(a*4),u=new Float32Array(a);s.forEach((g,p)=>{l.set([g[0],g[1],g[2]],p*3),c.set([g[3],g[4],g[5],g[6]],p*4),u[p]=g[7]});const h=new as(1,1),f=new hp;f.index=h.index,f.setAttribute("position",h.getAttribute("position")),f.setAttribute("iPos",new Ho(l,3)),f.setAttribute("iData",new Ho(c,4)),f.setAttribute("iKind",new Ho(u,1)),f.instanceCount=a;const d=new xt({uniforms:n,vertexShader:`
      ${Xn}
      attribute vec3 iPos; attribute vec4 iData; attribute float iKind;
      varying vec2 vQuad; varying vec2 vLeafUv; varying vec2 vCardUv; varying float vSeed; varying float vShade; varying float vKind;
      varying float vFog; varying vec3 vFogCol; varying float vBeam; varying vec3 vHolo; varying vec3 vHoloDir; varying vec3 vView;
      void main() {
        vec2 corner = position.xy;
        float c = cos(iData.y), s = sin(iData.y);
        vec2 rc = vec2(corner.x * c - corner.y * s, corner.x * s + corner.y * c);
        vec3 centre = iPos;
        float sway = iKind < 0.5 ? 0.06 : 0.03;
        centre.x += sin(uTime * 0.6 + iData.z) * sway * iData.x * 0.3;
        vec4 mv = viewMatrix * vec4(centre, 1.0);
        vec2 stretch = iKind > 1.5 ? vec2(1.0, 0.75) : vec2(1.0, 0.86);
        mv.xy += corner * iData.x * stretch;
        vQuad = corner * 2.0;
        vLeafUv = ((iKind > 1.5 ? corner : rc) + 0.5) * iData.x * 0.3 + iData.z;
        vCardUv = rc + 0.5;
        vSeed = iData.z; vShade = iData.w; vKind = iKind;
        // per-card lighting
        vFog = fogAmount(centre);
        vFogCol = fogColorAt(centre);
        vBeam = beamField(centre);
        vec3 hl = uHoloPos - centre;
        float d2 = dot(hl, hl);
        vHoloDir = hl * inversesqrt(d2);
        vHolo = uHoloColor * (uHoloLight / (1.0 + d2 * 0.16));
        vView = normalize(cameraPosition - centre);
        gl_Position = projectionMatrix * mv;
      }`,fragmentShader:`
      ${Xn}
      uniform vec3 uLeaf;
      varying vec2 vQuad; varying vec2 vLeafUv; varying vec2 vCardUv; varying float vSeed; varying float vShade; varying float vKind;
      varying float vFog; varying vec3 vFogCol; varying float vBeam; varying vec3 vHolo; varying vec3 vHoloDir; varying vec3 vView;
      void main() {
        vec2 p = vQuad;
        float r = length(p);
        float leaf = 0.5;
        if (vKind > 1.5) {
          // grass tuft: a fan of tapered, bending blades rising from the card's foot
          vec2 q = p * 0.5 + 0.5;
          float cover = 0.0;
          for (int i = 0; i < 11; i++) {
            float fi = float(i);
            float h1 = hash12(vec2(vSeed, fi * 1.7));
            float h2 = hash12(vec2(fi * 3.1, vSeed * 1.3));
            float bx = 0.5 + (h1 - 0.5) * 0.5;
            float bh = 0.3 + 0.7 * h2;
            float lean = (h1 - 0.5) * 1.3;
            float y = q.y / bh;
            float xc = bx + lean * y * y * 0.5;
            float w = 0.032 * (1.0 - y) + 0.002;
            cover = max(cover, step(y, 1.0) * step(abs(q.x - xc), w));
          }
          if (cover < 0.5) discard;
        } else {
          // clump silhouette from two octaves of lumps, serrated by two layers of elongated leaf cells
          vec4 lump = texture2D(uNoise, vCardUv * 0.42 + vSeed * 0.13);
          float mid = texture2D(uNoise, vCardUv * 1.25 + vSeed * 0.71).b;
          float R = clamp(0.72 + (lump.r - 0.5) * 0.46 + (lump.g - 0.5) * 0.3 + (mid - 0.5) * 0.22, 0.38, 0.9);
          float shape = r / R;
          float c1 = texture2D(uNoise, vLeafUv * vec2(0.9, 1.7)).a;
          float c2 = texture2D(uNoise, vLeafUv * vec2(1.6, 0.85) + vec2(0.37, 0.61)).a;
          leaf = min(c1, c2);
          if (shape + leaf * 0.38 > 1.06) discard;
          if (leaf > 0.68 && shape > 0.5) discard;
        }
        vec3 nv = vKind > 1.5 ? vec3(0.0, 0.35, 1.0) : normalize(vec3(p * 0.55, 0.75 + 0.5 * sqrt(max(1.0 - r * r, 0.0))));
        vec3 N = normalize((vec4(nv, 0.0) * viewMatrix).xyz);
        vec3 alb = uLeaf * vShade * (0.72 + 0.56 * (1.0 - leaf));
        float ao = mix(0.5, 1.0, clamp(p.y * 0.5 + 0.6, 0.0, 1.0)) * mix(0.75, 1.0, r);
        float hemi = N.y * 0.5 + 0.5;
        float wrap = max(dot(N, uBeamDir) * 0.5 + 0.5, 0.0);
        vec3 light = mix(uAmbGround, uAmbSky, hemi) * 0.7 + uKeyColor * (wrap * wrap * uKeyStrength * 0.32);
        light += uBeamColor * (vBeam * max(dot(N, uBeamDir) * 0.8 + 0.2, 0.0) * 1.7);
        light += vHolo * max(dot(N, vHoloDir) * 0.7 + 0.3, 0.0);
        vec3 col = alb * light * ao;
        float back = pow(max(dot(-vView, uBeamDir), 0.0), 3.0);
        col += uKeyColor * alb * back * smoothstep(0.35, 0.95, r) * 2.5 * uKeyStrength;
        col = mix(col, vFogCol, vFog);
        gl_FragColor = vec4(col, 1.0);
      }`}),v=new Gt(f,d);return v.name="foliage",v.frustumCulled=!1,{mesh:v,count:a,dispose(){f.dispose(),h.dispose(),d.dispose()}}}function ob(n,e){const i=[],r=[];for(let h=0;h<=10;h++)if(i.push(-1,h/10,0,1,h/10,0),h<10){const f=h*2;r.push(f,f+1,f+2,f+1,f+3,f+2)}const s=new hp;s.setAttribute("position",new nt(i,3)),s.setIndex(r);const o=Math.min(e.beams,Nl.length),a=new Float32Array(o*4),l=new Float32Array(o);for(let h=0;h<o;h++)a.set(Nl[h],h*4),l[h]=h*.173+.05;s.setAttribute("iBeam",new Ho(a,4)),s.setAttribute("iSeed",new Ho(l,1)),s.instanceCount=o;const c=new xt({uniforms:{...n,uBeamOpacity:{value:.5}},vertexShader:`
      ${Xn}
      attribute vec4 iBeam; attribute float iSeed;
      varying vec2 vB; varying float vW; varying float vSeed; varying vec3 vWorld; varying float vAtten;
      void main() {
        float along = position.y;
        vec3 g = vec3(iBeam.x, -0.3, iBeam.y);
        float L = min(34.0 / max(uBeamDir.y, 0.25), 80.0);
        vec3 P = g + uBeamDir * (along * L);
        float r = iBeam.z * mix(1.0, 0.62, clamp(along * L / 34.0, 0.0, 1.0));
        vec3 toCam = normalize(cameraPosition - P);
        vec3 sideDir = normalize(cross(uBeamDir, toCam));
        P += sideDir * position.x * r * 1.5;
        vWorld = P; vB = position.xy; vW = iBeam.w; vSeed = iSeed;
        // fog and near-camera fade vary slowly along the ribbon: evaluate per vertex
        float dist = length(P - cameraPosition);
        vAtten = smoothstep(2.5, 10.0, dist) * (1.0 - fogAmount(P) * 0.55);
        gl_Position = projectionMatrix * viewMatrix * vec4(P, 1.0);
      }`,fragmentShader:`
      ${Xn}
      uniform float uBeamOpacity;
      varying vec2 vB; varying float vW; varying float vSeed; varying vec3 vWorld; varying float vAtten;
      void main() {
        float x = vB.x * 1.5;
        float prof = exp(-x * x * 2.2) * 0.62 + exp(-x * x * 10.0) * 0.55; // soft halo + brighter core
        float along = vB.y;
        // soft contact with the ground and the kund (ribbons would otherwise cut hard lines through them)
        float rr = length(vWorld.xz);
        float kundClear = rr < 4.6 ? vWorld.y - 0.6 : length(vec2(rr - 4.6, max(vWorld.y - 0.6, 0.0)));
        float above = min(vWorld.y, kundClear);
        float ends = smoothstep(0.0, 2.2, above) * (1.0 - smoothstep(14.0, 30.0, vWorld.y));
        if (prof * ends < 0.002) discard;
        float n = texture2D(uNoise, vec2(vB.x * 0.22 + vSeed, along * 1.6 - uTime * 0.01)).r;
        float n2 = texture2D(uNoise, vec2(vB.x * 0.6 + vSeed * 1.3, along * 5.0 - uTime * 0.025)).g;
        float streak = 0.45 + 0.75 * n * (0.65 + 0.7 * n2);
        float I = prof * ends * streak * vAtten * vW * uBeamStrength * uBeamOpacity;
        gl_FragColor = vec4(uBeamColor * I, 1.0);
      }`,transparent:!0,depthWrite:!1,blending:Zr,side:Tn}),u=new Gt(s,c);return u.name="beams",u.frustumCulled=!1,u.renderOrder=2,{mesh:u,count:o,dispose(){s.dispose(),c.dispose()}}}const r0=[[-62,8,.3],[-44,7,.32],[-30,6,.36],[-19,5,.4],[-11,3.8,.36],[-5.2,2.6,.3],[6.2,1.2,.22]];function ab(n,e){const t=r0.filter((h,f)=>f%e.mistStride===0||f===r0.length-1),i=[],r=[],s=[],o=[];let a=0;t.forEach(([h,f,d],v)=>{const g=26+Math.max(0,-h)*.75,p=-g,m=g,x=-.4,_=f;i.push(p,x,h,m,x,h,p,_,h,m,_,h),r.push(p,0,m,0,p,1,m,1);for(let y=0;y<4;y++)s.push(v*7.31+.2,d,f);o.push(a,a+1,a+2,a+1,a+3,a+2),a+=4});const l=new Et;l.setAttribute("position",new nt(i,3)),l.setAttribute("uv",new nt(r,2)),l.setAttribute("aSheet",new nt(s,3)),l.setIndex(o);const c=new xt({uniforms:n,vertexShader:`
      attribute vec3 aSheet;
      varying vec2 vUv; varying vec3 vSheet; varying vec3 vWorld;
      void main() {
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vWorld = wp.xyz; vUv = uv; vSheet = aSheet;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,fragmentShader:`
      ${Xn}
      uniform float uMist;
      varying vec2 vUv; varying vec3 vSheet; varying vec3 vWorld;
      void main() {
        float v = vUv.y;
        float seed = vSheet.x;
        float hgt = vSheet.z;
        float vert = smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.18, 1.0, v));
        float x = vUv.x;
        float n = texture2D(uNoise, vec2(x * 0.018 + uTime * 0.0035 + seed, v * hgt * 0.035 + seed * 0.3)).r;
        float n2 = texture2D(uNoise, vec2(x * 0.05 - uTime * 0.006 + seed * 2.0, v * hgt * 0.09 - uTime * 0.004)).g;
        float dens = smoothstep(0.42, 0.95, n * 0.75 + n2 * 0.45) * vert;
        if (dens < 0.004) discard;
        float bl = beamField(vWorld);
        // the hologram lights the mist mostly after dark; by day that glow sat right behind the
        // machine and washed it out
        vec3 c = fogColorAt(vWorld) * 1.04 + uBeamColor * bl * 0.55 + holoLight(vWorld, vec3(0.0, 0.0, 1.0)) * (0.12 + 0.48 * uNight);
        float dist = length(vWorld - cameraPosition);
        float a = dens * vSheet.y * uMist * smoothstep(3.0, 8.0, dist);
        gl_FragColor = vec4(c, clamp(a, 0.0, 1.0));
      }`,transparent:!0,depthWrite:!1}),u=new Gt(l,c);return u.name="mist",u.frustumCulled=!1,u.renderOrder=1,{mesh:u,dispose(){l.dispose(),c.dispose()}}}function lb(n,e){const t=Mr(512),i=e.dust,r=new Float32Array(i*3),s=new Float32Array(i*4);for(let c=0;c<i;c++){const u=t()<.55,h=u?Le(t,-7,7):Le(t,-16,16),f=u?Le(t,-9,5):Le(t,-34,6),d=u?Le(t,.2,7):Le(t,.2,13);r.set([h,d,f],c*3),s.set([t(),t(),t(),Le(t,.6,1.4)],c*4)}const o=new Et;o.setAttribute("position",new kt(r,3)),o.setAttribute("aSeed",new kt(s,4));const a=new xt({uniforms:{...n,uScale:{value:900}},vertexShader:`
      ${Xn}
      uniform float uScale;
      attribute vec4 aSeed;
      varying float vI; varying vec3 vC;
      void main() {
        vec3 p = position;
        float t = uTime;
        p += vec3(sin(t * 0.13 + aSeed.x * 40.0), sin(t * 0.09 + aSeed.y * 40.0) * 0.6, cos(t * 0.11 + aSeed.z * 40.0)) * 0.6;
        p.y += mod(t * 0.04 * (aSeed.w - 0.5), 1.0) * 0.4;
        float bl = beamField(p);
        vec3 hp = p - uHoloPos;
        float holo = uHoloLight * 0.6 / (1.0 + dot(hp, hp) * 0.35);
        float tw = 0.6 + 0.4 * sin(t * (0.8 + aSeed.x * 2.0) + aSeed.y * 30.0);
        vI = (0.05 + bl * 1.6 + holo) * tw * (1.0 - fogAmount(p) * 0.7);
        vC = mix(uBeamColor, uHoloColor, clamp(holo / (bl + holo + 1e-3), 0.0, 1.0));
        vec4 mv = viewMatrix * vec4(p, 1.0);
        gl_PointSize = clamp(uScale * 0.022 * aSeed.w / -mv.z, 0.0, 9.0);
        gl_Position = projectionMatrix * mv;
      }`,fragmentShader:`
      varying float vI; varying vec3 vC;
      void main() {
        vec2 q = gl_PointCoord * 2.0 - 1.0;
        float d = dot(q, q);
        if (d > 1.0) discard;
        float a = exp(-d * 4.0);
        gl_FragColor = vec4(vC * vI * a, 1.0);
      }`,transparent:!0,depthWrite:!1,blending:Zr}),l=new Yl(o,a);return l.name="dust",l.frustumCulled=!1,l.renderOrder=3,{mesh:l,mat:a,dispose(){o.dispose(),a.dispose()}}}function cb(n){const e=Mr(2026),t=[],i=[],r=[];let s=0,o=null;const a=(v,g,p,m,x,_,y,C)=>{t.push(...v,...g,...p,...m),i.push(...x,..._,...y,...C),r.push(s,s+1,s+2,s+1,s+3,s+2),s+=4};WM.forEach((v,g)=>{const p=Math.max(bm(v.x,v.z),0)+2,m=v.floors*3.3+2.4,x=14,_=v.x-v.w/2,y=v.x+v.w/2,C=v.z,M=v.z-x,w=p-6,P=p+m,I=g*3.17+e();a([_,w,C],[y,w,C],[_,P,C],[y,P,C],[0,w-p,I,0],[v.w,w-p,I,0],[0,m,I,0],[v.w,m,I,0]),a([_,w,M],[_,w,C],[_,P,M],[_,P,C],[0,w-p,I+1,1],[x,w-p,I+1,1],[0,m,I+1,1],[x,m,I+1,1]),a([y,w,C],[y,w,M],[y,P,C],[y,P,M],[0,w-p,I+2,1],[x,w-p,I+2,1],[0,m,I+2,1],[x,m,I+2,1]),(!o||v.floors>o.floors)&&(o={p:[v.x,P+1.2,v.z-x/2],floors:v.floors})});const l=new Et;l.setAttribute("position",new nt(t,3)),l.setAttribute("aFace",new nt(i,4)),l.setIndex(r);const c=new xt({uniforms:n,vertexShader:`
      attribute vec4 aFace;
      varying vec4 vFace; varying vec3 vWorld;
      void main() {
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vWorld = wp.xyz; vFace = aFace;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,fragmentShader:`
      ${Xn}
      varying vec4 vFace; varying vec3 vWorld;
      void main() {
        vec2 cell = vec2(vFace.x / 2.7, (vFace.y - 1.0) / 3.3);
        vec2 f = fract(cell), id = floor(cell);
        float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.3, f.y) * step(f.y, 0.74) * step(0.0, id.y);
        float h = hash12(id + vFace.z * 17.0);
        float lit = step(0.7, h) * win;
        vec3 wcol = mix(vec3(1.0, 0.76, 0.48), vec3(0.82, 0.9, 1.0), step(0.62, hash12(id * 1.7 + vFace.z)));
        float side = vFace.w > 0.5 ? 0.7 : 1.0;
        // by day the campus dissolves completely into the haze; after dusk it reads as a dark
        // block with a scatter of lit windows
        float vis = smoothstep(0.15, 0.7, uNight);
        if (vis < 0.01) discard;
        float fog = max(fogAmount(vWorld), 0.86 - 0.1 * vis);
        vec3 col = mix(uFogColor * 0.5 * side, fogColorAt(vWorld), fog);
        col += wcol * lit * uNight * (0.6 + 0.4 * h) * 1.1 * side;
        col = mix(fogColorAt(vWorld), col, vis);
        gl_FragColor = vec4(col, 1.0);
      }`}),u=new Gt(l,c);u.name="campus",u.frustumCulled=!1;const h=new Et;h.setAttribute("position",new nt(o.p,3));const f=new xt({uniforms:{...n,uScale:{value:900}},vertexShader:`
      ${Xn}
      uniform float uScale;
      varying float vI;
      void main() {
        vI = step(0.55, fract(uTime * 0.55)) * uNight * (1.0 - fogAmount(position) * 0.5);
        vec4 mv = viewMatrix * vec4(position, 1.0);
        gl_PointSize = clamp(uScale * 1.6 / -mv.z, 3.0, 7.0) * step(0.02, uNight);
        gl_Position = projectionMatrix * mv;
      }`,fragmentShader:`
      varying float vI;
      void main() {
        vec2 q = gl_PointCoord * 2.0 - 1.0;
        gl_FragColor = vec4(vec3(1.0, 0.16, 0.1) * vI * exp(-dot(q, q) * 3.0) * 3.0, 1.0);
      }`,transparent:!0,depthWrite:!1,blending:Zr}),d=new Yl(h,f);return d.name="campus-beacon",d.frustumCulled=!1,u.add(d),{mesh:u,mat:f,dispose(){l.dispose(),c.dispose(),h.dispose(),f.dispose()}}}function ub(n,e){const t=new Zn;t.name="atmosphere";const i=ab(n,e),r=lb(n,e),s=cb(n);return t.add(i.mesh,r.mesh,s.mesh),{group:t,setPixelScale(o){r.mat.uniforms.uScale.value=o,s.mat.uniforms.uScale.value=o},dispose(){i.dispose(),r.dispose(),s.dispose()}}}/**
 * postprocessing v6.36.4 build Tue Nov 05 2024
 * https://github.com/pmndrs/postprocessing
 * Copyright 2015-2024 Raoul van Rüschen
 * @license Zlib
 */var tu=1/1e3,hb=1e3,fb=class{constructor(){this.startTime=performance.now(),this.previousTime=0,this.currentTime=0,this._delta=0,this._elapsed=0,this._fixedDelta=1e3/60,this.timescale=1,this.useFixedDelta=!1,this._autoReset=!1}get autoReset(){return this._autoReset}set autoReset(n){typeof document<"u"&&document.hidden!==void 0&&(n?document.addEventListener("visibilitychange",this):document.removeEventListener("visibilitychange",this),this._autoReset=n)}get delta(){return this._delta*tu}get fixedDelta(){return this._fixedDelta*tu}set fixedDelta(n){this._fixedDelta=n*hb}get elapsed(){return this._elapsed*tu}update(n){this.useFixedDelta?this._delta=this.fixedDelta:(this.previousTime=this.currentTime,this.currentTime=(n!==void 0?n:performance.now())-this.startTime,this._delta=this.currentTime-this.previousTime),this._delta*=this.timescale,this._elapsed+=this._delta}reset(){this._delta=0,this._elapsed=0,this.currentTime=performance.now()-this.startTime}getDelta(){return this.delta}getElapsed(){return this.elapsed}handleEvent(n){document.hidden||(this.currentTime=performance.now()-this.startTime)}dispose(){this.autoReset=!1}},db=(()=>{const n=new Float32Array([-1,-1,0,3,-1,0,-1,3,0]),e=new Float32Array([0,0,2,0,0,2]),t=new Et;return t.setAttribute("position",new kt(n,3)),t.setAttribute("uv",new kt(e,2)),t})(),ai=class wh{static get fullscreenGeometry(){return db}constructor(e="Pass",t=new Zu,i=new Nh){this.name=e,this.renderer=null,this.scene=t,this.camera=i,this.screen=null,this.rtt=!0,this.needsSwap=!0,this.needsDepthTexture=!1,this.enabled=!0}get renderToScreen(){return!this.rtt}set renderToScreen(e){if(this.rtt===e){const t=this.fullscreenMaterial;t!==null&&(t.needsUpdate=!0),this.rtt=!e}}set mainScene(e){}set mainCamera(e){}setRenderer(e){this.renderer=e}isEnabled(){return this.enabled}setEnabled(e){this.enabled=e}get fullscreenMaterial(){return this.screen!==null?this.screen.material:null}set fullscreenMaterial(e){let t=this.screen;t!==null?t.material=e:(t=new Gt(wh.fullscreenGeometry,e),t.frustumCulled=!1,this.scene===null&&(this.scene=new Zu),this.scene.add(t),this.screen=t)}getFullscreenMaterial(){return this.fullscreenMaterial}setFullscreenMaterial(e){this.fullscreenMaterial=e}getDepthTexture(){return null}setDepthTexture(e,t=ha){}render(e,t,i,r,s){throw new Error("Render method not implemented!")}setSize(e,t){}initialize(e,t,i){}dispose(){for(const e of Object.keys(this)){const t=this[e];(t instanceof Sn||t instanceof os||t instanceof sn||t instanceof wh)&&this[e].dispose()}this.fullscreenMaterial!==null&&this.fullscreenMaterial.dispose()}},pb=class extends ai{constructor(){super("ClearMaskPass",null,null),this.needsSwap=!1}render(n,e,t,i,r){const s=n.state.buffers.stencil;s.setLocked(!1),s.setTest(!1)}},mb=`#include <common>
#include <dithering_pars_fragment>
#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D inputBuffer;
#else
uniform lowp sampler2D inputBuffer;
#endif
uniform float opacity;varying vec2 vUv;void main(){vec4 texel=texture2D(inputBuffer,vUv);gl_FragColor=opacity*texel;
#include <colorspace_fragment>
#include <dithering_fragment>
}`,wm="varying vec2 vUv;void main(){vUv=position.xy*0.5+0.5;gl_Position=vec4(position.xy,1.0,1.0);}",Em=class extends xt{constructor(){super({name:"CopyMaterial",uniforms:{inputBuffer:new it(null),opacity:new it(1)},blending:An,toneMapped:!1,depthWrite:!1,depthTest:!1,fragmentShader:mb,vertexShader:wm})}set inputBuffer(n){this.uniforms.inputBuffer.value=n}setInputBuffer(n){this.uniforms.inputBuffer.value=n}getOpacity(n){return this.uniforms.opacity.value}setOpacity(n){this.uniforms.opacity.value=n}},gb=class extends ai{constructor(n,e=!0){super("CopyPass"),this.fullscreenMaterial=new Em,this.needsSwap=!1,this.renderTarget=n,n===void 0&&(this.renderTarget=new Sn(1,1,{minFilter:hn,magFilter:hn,stencilBuffer:!1,depthBuffer:!1}),this.renderTarget.texture.name="CopyPass.Target"),this.autoResize=e}get resize(){return this.autoResize}set resize(n){this.autoResize=n}get texture(){return this.renderTarget.texture}getTexture(){return this.renderTarget.texture}setAutoResizeEnabled(n){this.autoResize=n}render(n,e,t,i,r){this.fullscreenMaterial.inputBuffer=e.texture,n.setRenderTarget(this.renderToScreen?null:this.renderTarget),n.render(this.scene,this.camera)}setSize(n,e){this.autoResize&&this.renderTarget.setSize(n,e)}initialize(n,e,t){t!==void 0&&(this.renderTarget.texture.type=t,t!==on?this.fullscreenMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1":n!==null&&n.outputColorSpace===wt&&(this.renderTarget.texture.colorSpace=wt))}},s0=new st,Tm=class extends ai{constructor(n=!0,e=!0,t=!1){super("ClearPass",null,null),this.needsSwap=!1,this.color=n,this.depth=e,this.stencil=t,this.overrideClearColor=null,this.overrideClearAlpha=-1}setClearFlags(n,e,t){this.color=n,this.depth=e,this.stencil=t}getOverrideClearColor(){return this.overrideClearColor}setOverrideClearColor(n){this.overrideClearColor=n}getOverrideClearAlpha(){return this.overrideClearAlpha}setOverrideClearAlpha(n){this.overrideClearAlpha=n}render(n,e,t,i,r){const s=this.overrideClearColor,o=this.overrideClearAlpha,a=n.getClearAlpha(),l=s!==null,c=o>=0;l?(n.getClearColor(s0),n.setClearColor(s,c?o:a)):c&&n.setClearAlpha(o),n.setRenderTarget(this.renderToScreen?null:e),n.clear(this.color,this.depth,this.stencil),l?n.setClearColor(s0,a):c&&n.setClearAlpha(a)}},vb=class extends ai{constructor(n,e){super("MaskPass",n,e),this.needsSwap=!1,this.clearPass=new Tm(!1,!1,!0),this.inverse=!1}set mainScene(n){this.scene=n}set mainCamera(n){this.camera=n}get inverted(){return this.inverse}set inverted(n){this.inverse=n}get clear(){return this.clearPass.enabled}set clear(n){this.clearPass.enabled=n}getClearPass(){return this.clearPass}isInverted(){return this.inverted}setInverted(n){this.inverted=n}render(n,e,t,i,r){const s=n.getContext(),o=n.state.buffers,a=this.scene,l=this.camera,c=this.clearPass,u=this.inverted?0:1,h=1-u;o.color.setMask(!1),o.depth.setMask(!1),o.color.setLocked(!0),o.depth.setLocked(!0),o.stencil.setTest(!0),o.stencil.setOp(s.REPLACE,s.REPLACE,s.REPLACE),o.stencil.setFunc(s.ALWAYS,u,4294967295),o.stencil.setClear(h),o.stencil.setLocked(!0),this.clearPass.enabled&&(this.renderToScreen?c.render(n,null):(c.render(n,e),c.render(n,t))),this.renderToScreen?(n.setRenderTarget(null),n.render(a,l)):(n.setRenderTarget(e),n.render(a,l),n.setRenderTarget(t),n.render(a,l)),o.color.setLocked(!1),o.depth.setLocked(!1),o.stencil.setLocked(!1),o.stencil.setFunc(s.EQUAL,1,4294967295),o.stencil.setOp(s.KEEP,s.KEEP,s.KEEP),o.stencil.setLocked(!0)}},_b=class{constructor(n=null,{depthBuffer:e=!0,stencilBuffer:t=!1,multisampling:i=0,frameBufferType:r}={}){this.renderer=null,this.inputBuffer=this.createBuffer(e,t,r,i),this.outputBuffer=this.inputBuffer.clone(),this.copyPass=new gb,this.depthTexture=null,this.passes=[],this.timer=new fb,this.autoRenderToScreen=!0,this.setRenderer(n)}get multisampling(){return this.inputBuffer.samples||0}set multisampling(n){const e=this.inputBuffer,t=this.multisampling;t>0&&n>0?(this.inputBuffer.samples=n,this.outputBuffer.samples=n,this.inputBuffer.dispose(),this.outputBuffer.dispose()):t!==n&&(this.inputBuffer.dispose(),this.outputBuffer.dispose(),this.inputBuffer=this.createBuffer(e.depthBuffer,e.stencilBuffer,e.texture.type,n),this.inputBuffer.depthTexture=this.depthTexture,this.outputBuffer=this.inputBuffer.clone())}getTimer(){return this.timer}getRenderer(){return this.renderer}setRenderer(n){if(this.renderer=n,n!==null){const e=n.getSize(new we),t=n.getContext().getContextAttributes().alpha,i=this.inputBuffer.texture.type;i===on&&n.outputColorSpace===wt&&(this.inputBuffer.texture.colorSpace=wt,this.outputBuffer.texture.colorSpace=wt,this.inputBuffer.dispose(),this.outputBuffer.dispose()),n.autoClear=!1,this.setSize(e.width,e.height);for(const r of this.passes)r.initialize(n,t,i)}}replaceRenderer(n,e=!0){const t=this.renderer,i=t.domElement.parentNode;return this.setRenderer(n),e&&i!==null&&(i.removeChild(t.domElement),i.appendChild(n.domElement)),t}createDepthTexture(){const n=this.depthTexture=new Oh;return this.inputBuffer.depthTexture=n,this.inputBuffer.dispose(),this.inputBuffer.stencilBuffer?(n.format=Qr,n.type=Jr):n.type=xr,n}deleteDepthTexture(){if(this.depthTexture!==null){this.depthTexture.dispose(),this.depthTexture=null,this.inputBuffer.depthTexture=null,this.inputBuffer.dispose();for(const n of this.passes)n.setDepthTexture(null)}}createBuffer(n,e,t,i){const r=this.renderer,s=r===null?new we:r.getDrawingBufferSize(new we),o={minFilter:hn,magFilter:hn,stencilBuffer:e,depthBuffer:n,type:t},a=new Sn(s.width,s.height,o);return i>0&&(a.ignoreDepthForMultisampleCopy=!1,a.samples=i),t===on&&r!==null&&r.outputColorSpace===wt&&(a.texture.colorSpace=wt),a.texture.name="EffectComposer.Buffer",a.texture.generateMipmaps=!1,a}setMainScene(n){for(const e of this.passes)e.mainScene=n}setMainCamera(n){for(const e of this.passes)e.mainCamera=n}addPass(n,e){const t=this.passes,i=this.renderer,r=i.getDrawingBufferSize(new we),s=i.getContext().getContextAttributes().alpha,o=this.inputBuffer.texture.type;if(n.setRenderer(i),n.setSize(r.width,r.height),n.initialize(i,s,o),this.autoRenderToScreen&&(t.length>0&&(t[t.length-1].renderToScreen=!1),n.renderToScreen&&(this.autoRenderToScreen=!1)),e!==void 0?t.splice(e,0,n):t.push(n),this.autoRenderToScreen&&(t[t.length-1].renderToScreen=!0),n.needsDepthTexture||this.depthTexture!==null)if(this.depthTexture===null){const a=this.createDepthTexture();for(n of t)n.setDepthTexture(a)}else n.setDepthTexture(this.depthTexture)}removePass(n){const e=this.passes,t=e.indexOf(n);if(t!==-1&&e.splice(t,1).length>0){if(this.depthTexture!==null){const s=(a,l)=>a||l.needsDepthTexture;e.reduce(s,!1)||(n.getDepthTexture()===this.depthTexture&&n.setDepthTexture(null),this.deleteDepthTexture())}this.autoRenderToScreen&&t===e.length&&(n.renderToScreen=!1,e.length>0&&(e[e.length-1].renderToScreen=!0))}}removeAllPasses(){const n=this.passes;this.deleteDepthTexture(),n.length>0&&(this.autoRenderToScreen&&(n[n.length-1].renderToScreen=!1),this.passes=[])}render(n){const e=this.renderer,t=this.copyPass;let i=this.inputBuffer,r=this.outputBuffer,s=!1,o,a,l;n===void 0&&(this.timer.update(),n=this.timer.getDelta());for(const c of this.passes)c.enabled&&(c.render(e,i,r,n,s),c.needsSwap&&(s&&(t.renderToScreen=c.renderToScreen,o=e.getContext(),a=e.state.buffers.stencil,a.setFunc(o.NOTEQUAL,1,4294967295),t.render(e,i,r,n,s),a.setFunc(o.EQUAL,1,4294967295)),l=i,i=r,r=l),c instanceof vb?s=!0:c instanceof pb&&(s=!1))}setSize(n,e,t){const i=this.renderer,r=i.getSize(new we);(n===void 0||e===void 0)&&(n=r.width,e=r.height),(r.width!==n||r.height!==e)&&i.setSize(n,e,t);const s=i.getDrawingBufferSize(new we);this.inputBuffer.setSize(s.width,s.height),this.outputBuffer.setSize(s.width,s.height);for(const o of this.passes)o.setSize(s.width,s.height)}reset(){this.dispose(),this.autoRenderToScreen=!0}dispose(){for(const n of this.passes)n.dispose();this.passes=[],this.inputBuffer!==null&&this.inputBuffer.dispose(),this.outputBuffer!==null&&this.outputBuffer.dispose(),this.deleteDepthTexture(),this.copyPass.dispose(),this.timer.dispose(),ai.fullscreenGeometry.dispose()}},vr={NONE:0,DEPTH:1,CONVOLUTION:2},ft={FRAGMENT_HEAD:"FRAGMENT_HEAD",FRAGMENT_MAIN_UV:"FRAGMENT_MAIN_UV",FRAGMENT_MAIN_IMAGE:"FRAGMENT_MAIN_IMAGE",VERTEX_HEAD:"VERTEX_HEAD",VERTEX_MAIN_SUPPORT:"VERTEX_MAIN_SUPPORT"},xb=class{constructor(){this.shaderParts=new Map([[ft.FRAGMENT_HEAD,null],[ft.FRAGMENT_MAIN_UV,null],[ft.FRAGMENT_MAIN_IMAGE,null],[ft.VERTEX_HEAD,null],[ft.VERTEX_MAIN_SUPPORT,null]]),this.defines=new Map,this.uniforms=new Map,this.blendModes=new Map,this.extensions=new Set,this.attributes=vr.NONE,this.varyings=new Set,this.uvTransformation=!1,this.readDepth=!1,this.colorSpace=wi}},nu=!1,o0=class{constructor(n=null){this.originalMaterials=new Map,this.material=null,this.materials=null,this.materialsBackSide=null,this.materialsDoubleSide=null,this.materialsFlatShaded=null,this.materialsFlatShadedBackSide=null,this.materialsFlatShadedDoubleSide=null,this.setMaterial(n),this.meshCount=0,this.replaceMaterial=e=>{if(e.isMesh){let t;if(e.material.flatShading)switch(e.material.side){case Tn:t=this.materialsFlatShadedDoubleSide;break;case Kt:t=this.materialsFlatShadedBackSide;break;default:t=this.materialsFlatShaded;break}else switch(e.material.side){case Tn:t=this.materialsDoubleSide;break;case Kt:t=this.materialsBackSide;break;default:t=this.materials;break}this.originalMaterials.set(e,e.material),e.isSkinnedMesh?e.material=t[2]:e.isInstancedMesh?e.material=t[1]:e.material=t[0],++this.meshCount}}}cloneMaterial(n){if(!(n instanceof xt))return n.clone();const e=n.uniforms,t=new Map;for(const r in e){const s=e[r].value;s.isRenderTargetTexture&&(e[r].value=null,t.set(r,s))}const i=n.clone();for(const r of t)e[r[0]].value=r[1],i.uniforms[r[0]].value=r[1];return i}setMaterial(n){if(this.disposeMaterials(),this.material=n,n!==null){const e=this.materials=[this.cloneMaterial(n),this.cloneMaterial(n),this.cloneMaterial(n)];for(const t of e)t.uniforms=Object.assign({},n.uniforms),t.side=zi;e[2].skinning=!0,this.materialsBackSide=e.map(t=>{const i=this.cloneMaterial(t);return i.uniforms=Object.assign({},n.uniforms),i.side=Kt,i}),this.materialsDoubleSide=e.map(t=>{const i=this.cloneMaterial(t);return i.uniforms=Object.assign({},n.uniforms),i.side=Tn,i}),this.materialsFlatShaded=e.map(t=>{const i=this.cloneMaterial(t);return i.uniforms=Object.assign({},n.uniforms),i.flatShading=!0,i}),this.materialsFlatShadedBackSide=e.map(t=>{const i=this.cloneMaterial(t);return i.uniforms=Object.assign({},n.uniforms),i.flatShading=!0,i.side=Kt,i}),this.materialsFlatShadedDoubleSide=e.map(t=>{const i=this.cloneMaterial(t);return i.uniforms=Object.assign({},n.uniforms),i.flatShading=!0,i.side=Tn,i})}}render(n,e,t){const i=n.shadowMap.enabled;if(n.shadowMap.enabled=!1,nu){const r=this.originalMaterials;this.meshCount=0,e.traverse(this.replaceMaterial),n.render(e,t);for(const s of r)s[0].material=s[1];this.meshCount!==r.size&&r.clear()}else{const r=e.overrideMaterial;e.overrideMaterial=this.material,n.render(e,t),e.overrideMaterial=r}n.shadowMap.enabled=i}disposeMaterials(){if(this.material!==null){const n=this.materials.concat(this.materialsBackSide).concat(this.materialsDoubleSide).concat(this.materialsFlatShaded).concat(this.materialsFlatShadedBackSide).concat(this.materialsFlatShadedDoubleSide);for(const e of n)e.dispose()}}dispose(){this.originalMaterials.clear(),this.disposeMaterials()}static get workaroundEnabled(){return nu}static set workaroundEnabled(n){nu=n}},nr=-1,yi=class extends Wi{constructor(n,e=nr,t=nr,i=1){super(),this.resizable=n,this.baseSize=new we(1,1),this.preferredSize=new we(e,t),this.target=this.preferredSize,this.s=i,this.effectiveSize=new we,this.addEventListener("change",()=>this.updateEffectiveSize()),this.updateEffectiveSize()}updateEffectiveSize(){const n=this.baseSize,e=this.preferredSize,t=this.effectiveSize,i=this.scale;e.width!==nr?t.width=e.width:e.height!==nr?t.width=Math.round(e.height*(n.width/Math.max(n.height,1))):t.width=Math.round(n.width*i),e.height!==nr?t.height=e.height:e.width!==nr?t.height=Math.round(e.width/Math.max(n.width/Math.max(n.height,1),1)):t.height=Math.round(n.height*i)}get width(){return this.effectiveSize.width}set width(n){this.preferredWidth=n}get height(){return this.effectiveSize.height}set height(n){this.preferredHeight=n}getWidth(){return this.width}getHeight(){return this.height}get scale(){return this.s}set scale(n){this.s!==n&&(this.s=n,this.preferredSize.setScalar(nr),this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}getScale(){return this.scale}setScale(n){this.scale=n}get baseWidth(){return this.baseSize.width}set baseWidth(n){this.baseSize.width!==n&&(this.baseSize.width=n,this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}getBaseWidth(){return this.baseWidth}setBaseWidth(n){this.baseWidth=n}get baseHeight(){return this.baseSize.height}set baseHeight(n){this.baseSize.height!==n&&(this.baseSize.height=n,this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}getBaseHeight(){return this.baseHeight}setBaseHeight(n){this.baseHeight=n}setBaseSize(n,e){(this.baseSize.width!==n||this.baseSize.height!==e)&&(this.baseSize.set(n,e),this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}get preferredWidth(){return this.preferredSize.width}set preferredWidth(n){this.preferredSize.width!==n&&(this.preferredSize.width=n,this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}getPreferredWidth(){return this.preferredWidth}setPreferredWidth(n){this.preferredWidth=n}get preferredHeight(){return this.preferredSize.height}set preferredHeight(n){this.preferredSize.height!==n&&(this.preferredSize.height=n,this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}getPreferredHeight(){return this.preferredHeight}setPreferredHeight(n){this.preferredHeight=n}setPreferredSize(n,e){(this.preferredSize.width!==n||this.preferredSize.height!==e)&&(this.preferredSize.set(n,e),this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height))}copy(n){this.s=n.scale,this.baseSize.set(n.baseWidth,n.baseHeight),this.preferredSize.set(n.preferredWidth,n.preferredHeight),this.dispatchEvent({type:"change"}),this.resizable.setSize(this.baseSize.width,this.baseSize.height)}static get AUTO_SIZE(){return nr}},yb=class{constructor(n=0){this.nextId=n}getNextId(){return this.nextId++}reset(n=0){return this.nextId=n,this}},iu=new yb(2),Sb=class extends Set{constructor(n,e=iu.getNextId()){super(),this.exclusive=!1,this._layer=e,(this._layer<1||this._layer>31)&&(console.warn("Layer out of range, resetting to 2"),iu.reset(2),this._layer=iu.getNextId()),n!==void 0&&this.set(n)}get layer(){return this._layer}set layer(n){const e=this._layer;for(const t of this)t.layers.disable(e),t.layers.enable(n);this._layer=n}getLayer(){return this.layer}setLayer(n){this.layer=n}isExclusive(){return this.exclusive}setExclusive(n){this.exclusive=n}clear(){const n=this.layer;for(const e of this)e.layers.disable(n);return super.clear()}set(n){this.clear();for(const e of n)this.add(e);return this}indexOf(n){return this.has(n)?0:-1}add(n){return this.exclusive?n.layers.set(this.layer):n.layers.enable(this.layer),super.add(n)}delete(n){return this.has(n)&&n.layers.disable(this.layer),super.delete(n)}toggle(n){let e;return this.has(n)?(this.delete(n),e=!1):(this.add(n),e=!0),e}setVisible(n){for(const e of this)n?e.layers.enable(0):e.layers.disable(0);return this}},Qe={ADD:0,ALPHA:1,AVERAGE:2,COLOR:3,COLOR_BURN:4,COLOR_DODGE:5,DARKEN:6,DIFFERENCE:7,DIVIDE:8,DST:9,EXCLUSION:10,HARD_LIGHT:11,HARD_MIX:12,HUE:13,INVERT:14,INVERT_RGB:15,LIGHTEN:16,LINEAR_BURN:17,LINEAR_DODGE:18,LINEAR_LIGHT:19,LUMINOSITY:20,MULTIPLY:21,NEGATION:22,NORMAL:23,OVERLAY:24,PIN_LIGHT:25,REFLECT:26,SATURATION:27,SCREEN:28,SOFT_LIGHT:29,SRC:30,SUBTRACT:31,VIVID_LIGHT:32},Mb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,x+y,opacity);}",bb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,y,min(y.a,opacity));}",wb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,(x+y)*0.5,opacity);}",Eb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec3 xHSL=RGBToHSL(x.rgb);vec3 yHSL=RGBToHSL(y.rgb);vec3 z=HSLToRGB(vec3(yHSL.rg,xHSL.b));return vec4(mix(x.rgb,z,opacity),y.a);}",Tb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 z=mix(step(0.0,y)*(1.0-min(vec4(1.0),(1.0-x)/y)),vec4(1.0),step(1.0,x));return mix(x,z,opacity);}",Ab="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 z=step(0.0,x)*mix(min(vec4(1.0),x/max(1.0-y,1e-9)),vec4(1.0),step(1.0,y));return mix(x,z,opacity);}",Cb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,min(x,y),opacity);}",Rb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,abs(x-y),opacity);}",Pb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,x/max(y,1e-12),opacity);}",Lb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,(x+y-2.0*x*y),opacity);}",Db="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 a=min(x,1.0),b=min(y,1.0);vec4 z=mix(2.0*a*b,1.0-2.0*(1.0-a)*(1.0-b),step(0.5,y));return mix(x,z,opacity);}",Ib="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,step(1.0,x+y),opacity);}",Ub="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec3 xHSL=RGBToHSL(x.rgb);vec3 yHSL=RGBToHSL(y.rgb);vec3 z=HSLToRGB(vec3(yHSL.r,xHSL.gb));return vec4(mix(x.rgb,z,opacity),y.a);}",Nb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,1.0-y,opacity);}",Fb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,y*(1.0-x),opacity);}",Ob="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,max(x,y),opacity);}",kb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,clamp(y+x-1.0,0.0,1.0),opacity);}",Bb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,min(x+y,1.0),opacity);}",zb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,clamp(2.0*y+x-1.0,0.0,1.0),opacity);}",Hb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec3 xHSL=RGBToHSL(x.rgb);vec3 yHSL=RGBToHSL(y.rgb);vec3 z=HSLToRGB(vec3(xHSL.rg,yHSL.b));return vec4(mix(x.rgb,z,opacity),y.a);}",Gb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,x*y,opacity);}",Vb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,1.0-abs(1.0-x-y),opacity);}",Wb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,y,opacity);}",Xb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 z=mix(2.0*y*x,1.0-2.0*(1.0-y)*(1.0-x),step(0.5,x));return mix(x,z,opacity);}",qb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 y2=2.0*y;vec4 z=mix(mix(y2,x,step(0.5*x,y)),max(vec4(0.0),y2-1.0),step(x,(y2-1.0)));return mix(x,z,opacity);}",$b="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 z=mix(min(x*x/max(1.0-y,1e-12),1.0),y,step(1.0,y));return mix(x,z,opacity);}",Yb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec3 xHSL=RGBToHSL(x.rgb);vec3 yHSL=RGBToHSL(y.rgb);vec3 z=HSLToRGB(vec3(xHSL.r,yHSL.g,xHSL.b));return vec4(mix(x.rgb,z,opacity),y.a);}",Kb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,x+y-min(x*y,1.0),opacity);}",jb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 y2=2.0*y;vec4 w=step(0.5,y);vec4 z=mix(x-(1.0-y2)*x*(1.0-x),mix(x+(y2-1.0)*(sqrt(x)-x),x+(y2-1.0)*x*((16.0*x-12.0)*x+3.0),w*(1.0-step(0.25,x))),w);return mix(x,z,opacity);}",Zb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return y;}",Jb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){return mix(x,max(x+y-1.0,0.0),opacity);}",Qb="vec4 blend(const in vec4 x,const in vec4 y,const in float opacity){vec4 z=mix(max(1.0-min((1.0-x)/(2.0*y),1.0),0.0),min(x/(2.0*(1.0-y)),1.0),step(0.5,y));return mix(x,z,opacity);}",ew=new Map([[Qe.ADD,Mb],[Qe.ALPHA,bb],[Qe.AVERAGE,wb],[Qe.COLOR,Eb],[Qe.COLOR_BURN,Tb],[Qe.COLOR_DODGE,Ab],[Qe.DARKEN,Cb],[Qe.DIFFERENCE,Rb],[Qe.DIVIDE,Pb],[Qe.DST,null],[Qe.EXCLUSION,Lb],[Qe.HARD_LIGHT,Db],[Qe.HARD_MIX,Ib],[Qe.HUE,Ub],[Qe.INVERT,Nb],[Qe.INVERT_RGB,Fb],[Qe.LIGHTEN,Ob],[Qe.LINEAR_BURN,kb],[Qe.LINEAR_DODGE,Bb],[Qe.LINEAR_LIGHT,zb],[Qe.LUMINOSITY,Hb],[Qe.MULTIPLY,Gb],[Qe.NEGATION,Vb],[Qe.NORMAL,Wb],[Qe.OVERLAY,Xb],[Qe.PIN_LIGHT,qb],[Qe.REFLECT,$b],[Qe.SATURATION,Yb],[Qe.SCREEN,Kb],[Qe.SOFT_LIGHT,jb],[Qe.SRC,Zb],[Qe.SUBTRACT,Jb],[Qe.VIVID_LIGHT,Qb]]),tw=class extends Wi{constructor(n,e=1){super(),this._blendFunction=n,this.opacity=new it(e)}getOpacity(){return this.opacity.value}setOpacity(n){this.opacity.value=n}get blendFunction(){return this._blendFunction}set blendFunction(n){this._blendFunction=n,this.dispatchEvent({type:"change"})}getBlendFunction(){return this.blendFunction}setBlendFunction(n){this.blendFunction=n}getShaderCode(){return ew.get(this.blendFunction)}},vf={MEDIUM:2,LARGE:3},nw=`#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D inputBuffer;
#else
uniform lowp sampler2D inputBuffer;
#endif
varying vec2 vUv0;varying vec2 vUv1;varying vec2 vUv2;varying vec2 vUv3;void main(){vec4 sum=texture2D(inputBuffer,vUv0);sum+=texture2D(inputBuffer,vUv1);sum+=texture2D(inputBuffer,vUv2);sum+=texture2D(inputBuffer,vUv3);gl_FragColor=sum*0.25;
#include <colorspace_fragment>
}`,iw="uniform vec4 texelSize;uniform float kernel;uniform float scale;varying vec2 vUv0;varying vec2 vUv1;varying vec2 vUv2;varying vec2 vUv3;void main(){vec2 uv=position.xy*0.5+0.5;vec2 dUv=(texelSize.xy*vec2(kernel)+texelSize.zw)*scale;vUv0=vec2(uv.x-dUv.x,uv.y+dUv.y);vUv1=vec2(uv.x+dUv.x,uv.y+dUv.y);vUv2=vec2(uv.x+dUv.x,uv.y-dUv.y);vUv3=vec2(uv.x-dUv.x,uv.y-dUv.y);gl_Position=vec4(position.xy,1.0,1.0);}",rw=[new Float32Array([0,0]),new Float32Array([0,1,1]),new Float32Array([0,1,1,2]),new Float32Array([0,1,2,2,3]),new Float32Array([0,1,2,3,4,4,5]),new Float32Array([0,1,2,3,4,5,7,8,9,10])],sw=class extends xt{constructor(n=new Ct){super({name:"KawaseBlurMaterial",uniforms:{inputBuffer:new it(null),texelSize:new it(new Ct),scale:new it(1),kernel:new it(0)},blending:An,toneMapped:!1,depthWrite:!1,depthTest:!1,fragmentShader:nw,vertexShader:iw}),this.setTexelSize(n.x,n.y),this.kernelSize=vf.MEDIUM}set inputBuffer(n){this.uniforms.inputBuffer.value=n}setInputBuffer(n){this.inputBuffer=n}get kernelSequence(){return rw[this.kernelSize]}get scale(){return this.uniforms.scale.value}set scale(n){this.uniforms.scale.value=n}getScale(){return this.uniforms.scale.value}setScale(n){this.uniforms.scale.value=n}getKernel(){return null}get kernel(){return this.uniforms.kernel.value}set kernel(n){this.uniforms.kernel.value=n}setKernel(n){this.kernel=n}setTexelSize(n,e){this.uniforms.texelSize.value.set(n,e,n*.5,e*.5)}setSize(n,e){const t=1/n,i=1/e;this.uniforms.texelSize.value.set(t,i,t*.5,i*.5)}},ow=class extends ai{constructor({kernelSize:n=vf.MEDIUM,resolutionScale:e=.5,width:t=yi.AUTO_SIZE,height:i=yi.AUTO_SIZE,resolutionX:r=t,resolutionY:s=i}={}){super("KawaseBlurPass"),this.renderTargetA=new Sn(1,1,{depthBuffer:!1}),this.renderTargetA.texture.name="Blur.Target.A",this.renderTargetB=this.renderTargetA.clone(),this.renderTargetB.texture.name="Blur.Target.B";const o=this.resolution=new yi(this,r,s,e);o.addEventListener("change",a=>this.setSize(o.baseWidth,o.baseHeight)),this._blurMaterial=new sw,this._blurMaterial.kernelSize=n,this.copyMaterial=new Em}getResolution(){return this.resolution}get blurMaterial(){return this._blurMaterial}set blurMaterial(n){this._blurMaterial=n}get dithering(){return this.copyMaterial.dithering}set dithering(n){this.copyMaterial.dithering=n}get kernelSize(){return this.blurMaterial.kernelSize}set kernelSize(n){this.blurMaterial.kernelSize=n}get width(){return this.resolution.width}set width(n){this.resolution.preferredWidth=n}get height(){return this.resolution.height}set height(n){this.resolution.preferredHeight=n}get scale(){return this.blurMaterial.scale}set scale(n){this.blurMaterial.scale=n}getScale(){return this.blurMaterial.scale}setScale(n){this.blurMaterial.scale=n}getKernelSize(){return this.kernelSize}setKernelSize(n){this.kernelSize=n}getResolutionScale(){return this.resolution.scale}setResolutionScale(n){this.resolution.scale=n}render(n,e,t,i,r){const s=this.scene,o=this.camera,a=this.renderTargetA,l=this.renderTargetB,c=this.blurMaterial,u=c.kernelSequence;let h=e;this.fullscreenMaterial=c;for(let f=0,d=u.length;f<d;++f){const v=f&1?l:a;c.kernel=u[f],c.inputBuffer=h.texture,n.setRenderTarget(v),n.render(s,o),h=v}this.fullscreenMaterial=this.copyMaterial,this.copyMaterial.inputBuffer=h.texture,n.setRenderTarget(this.renderToScreen?null:t),n.render(s,o)}setSize(n,e){const t=this.resolution;t.setBaseSize(n,e);const i=t.width,r=t.height;this.renderTargetA.setSize(i,r),this.renderTargetB.setSize(i,r),this.blurMaterial.setSize(n,e)}initialize(n,e,t){t!==void 0&&(this.renderTargetA.texture.type=t,this.renderTargetB.texture.type=t,t!==on?(this.blurMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1",this.copyMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1"):n!==null&&n.outputColorSpace===wt&&(this.renderTargetA.texture.colorSpace=wt,this.renderTargetB.texture.colorSpace=wt))}static get AUTO_SIZE(){return yi.AUTO_SIZE}},aw=`#include <common>
#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D inputBuffer;
#else
uniform lowp sampler2D inputBuffer;
#endif
#ifdef RANGE
uniform vec2 range;
#elif defined(THRESHOLD)
uniform float threshold;uniform float smoothing;
#endif
varying vec2 vUv;void main(){vec4 texel=texture2D(inputBuffer,vUv);float l=luminance(texel.rgb);
#ifdef RANGE
float low=step(range.x,l);float high=step(l,range.y);l*=low*high;
#elif defined(THRESHOLD)
l=smoothstep(threshold,threshold+smoothing,l)*l;
#endif
#ifdef COLOR
gl_FragColor=vec4(texel.rgb*clamp(l,0.0,1.0),l);
#else
gl_FragColor=vec4(l);
#endif
}`,lw=class extends xt{constructor(n=!1,e=null){super({name:"LuminanceMaterial",defines:{THREE_REVISION:ua.replace(/\D+/g,"")},uniforms:{inputBuffer:new it(null),threshold:new it(0),smoothing:new it(1),range:new it(null)},blending:An,toneMapped:!1,depthWrite:!1,depthTest:!1,fragmentShader:aw,vertexShader:wm}),this.colorOutput=n,this.luminanceRange=e}set inputBuffer(n){this.uniforms.inputBuffer.value=n}setInputBuffer(n){this.uniforms.inputBuffer.value=n}get threshold(){return this.uniforms.threshold.value}set threshold(n){this.smoothing>0||n>0?this.defines.THRESHOLD="1":delete this.defines.THRESHOLD,this.uniforms.threshold.value=n}getThreshold(){return this.threshold}setThreshold(n){this.threshold=n}get smoothing(){return this.uniforms.smoothing.value}set smoothing(n){this.threshold>0||n>0?this.defines.THRESHOLD="1":delete this.defines.THRESHOLD,this.uniforms.smoothing.value=n}getSmoothingFactor(){return this.smoothing}setSmoothingFactor(n){this.smoothing=n}get useThreshold(){return this.threshold>0||this.smoothing>0}set useThreshold(n){}get colorOutput(){return this.defines.COLOR!==void 0}set colorOutput(n){n?this.defines.COLOR="1":delete this.defines.COLOR,this.needsUpdate=!0}isColorOutputEnabled(n){return this.colorOutput}setColorOutputEnabled(n){this.colorOutput=n}get useRange(){return this.luminanceRange!==null}set useRange(n){this.luminanceRange=null}get luminanceRange(){return this.uniforms.range.value}set luminanceRange(n){n!==null?this.defines.RANGE="1":delete this.defines.RANGE,this.uniforms.range.value=n,this.needsUpdate=!0}getLuminanceRange(){return this.luminanceRange}setLuminanceRange(n){this.luminanceRange=n}},cw=class extends ai{constructor({renderTarget:n,luminanceRange:e,colorOutput:t,resolutionScale:i=1,width:r=yi.AUTO_SIZE,height:s=yi.AUTO_SIZE,resolutionX:o=r,resolutionY:a=s}={}){super("LuminancePass"),this.fullscreenMaterial=new lw(t,e),this.needsSwap=!1,this.renderTarget=n,this.renderTarget===void 0&&(this.renderTarget=new Sn(1,1,{depthBuffer:!1}),this.renderTarget.texture.name="LuminancePass.Target");const l=this.resolution=new yi(this,o,a,i);l.addEventListener("change",c=>this.setSize(l.baseWidth,l.baseHeight))}get texture(){return this.renderTarget.texture}getTexture(){return this.renderTarget.texture}getResolution(){return this.resolution}render(n,e,t,i,r){const s=this.fullscreenMaterial;s.inputBuffer=e.texture,n.setRenderTarget(this.renderToScreen?null:this.renderTarget),n.render(this.scene,this.camera)}setSize(n,e){const t=this.resolution;t.setBaseSize(n,e),this.renderTarget.setSize(t.width,t.height)}initialize(n,e,t){t!==void 0&&t!==on&&(this.renderTarget.texture.type=t,this.fullscreenMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1")}},uw=`#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D inputBuffer;
#else
uniform lowp sampler2D inputBuffer;
#endif
#define WEIGHT_INNER 0.125
#define WEIGHT_OUTER 0.0555555
varying vec2 vUv;varying vec2 vUv00;varying vec2 vUv01;varying vec2 vUv02;varying vec2 vUv03;varying vec2 vUv04;varying vec2 vUv05;varying vec2 vUv06;varying vec2 vUv07;varying vec2 vUv08;varying vec2 vUv09;varying vec2 vUv10;varying vec2 vUv11;float clampToBorder(const in vec2 uv){return float(uv.s>=0.0&&uv.s<=1.0&&uv.t>=0.0&&uv.t<=1.0);}void main(){vec4 c=vec4(0.0);vec4 w=WEIGHT_INNER*vec4(clampToBorder(vUv00),clampToBorder(vUv01),clampToBorder(vUv02),clampToBorder(vUv03));c+=w.x*texture2D(inputBuffer,vUv00);c+=w.y*texture2D(inputBuffer,vUv01);c+=w.z*texture2D(inputBuffer,vUv02);c+=w.w*texture2D(inputBuffer,vUv03);w=WEIGHT_OUTER*vec4(clampToBorder(vUv04),clampToBorder(vUv05),clampToBorder(vUv06),clampToBorder(vUv07));c+=w.x*texture2D(inputBuffer,vUv04);c+=w.y*texture2D(inputBuffer,vUv05);c+=w.z*texture2D(inputBuffer,vUv06);c+=w.w*texture2D(inputBuffer,vUv07);w=WEIGHT_OUTER*vec4(clampToBorder(vUv08),clampToBorder(vUv09),clampToBorder(vUv10),clampToBorder(vUv11));c+=w.x*texture2D(inputBuffer,vUv08);c+=w.y*texture2D(inputBuffer,vUv09);c+=w.z*texture2D(inputBuffer,vUv10);c+=w.w*texture2D(inputBuffer,vUv11);c+=WEIGHT_OUTER*texture2D(inputBuffer,vUv);gl_FragColor=c;
#include <colorspace_fragment>
}`,hw="uniform vec2 texelSize;varying vec2 vUv;varying vec2 vUv00;varying vec2 vUv01;varying vec2 vUv02;varying vec2 vUv03;varying vec2 vUv04;varying vec2 vUv05;varying vec2 vUv06;varying vec2 vUv07;varying vec2 vUv08;varying vec2 vUv09;varying vec2 vUv10;varying vec2 vUv11;void main(){vUv=position.xy*0.5+0.5;vUv00=vUv+texelSize*vec2(-1.0,1.0);vUv01=vUv+texelSize*vec2(1.0,1.0);vUv02=vUv+texelSize*vec2(-1.0,-1.0);vUv03=vUv+texelSize*vec2(1.0,-1.0);vUv04=vUv+texelSize*vec2(-2.0,2.0);vUv05=vUv+texelSize*vec2(0.0,2.0);vUv06=vUv+texelSize*vec2(2.0,2.0);vUv07=vUv+texelSize*vec2(-2.0,0.0);vUv08=vUv+texelSize*vec2(2.0,0.0);vUv09=vUv+texelSize*vec2(-2.0,-2.0);vUv10=vUv+texelSize*vec2(0.0,-2.0);vUv11=vUv+texelSize*vec2(2.0,-2.0);gl_Position=vec4(position.xy,1.0,1.0);}",fw=class extends xt{constructor(){super({name:"DownsamplingMaterial",uniforms:{inputBuffer:new it(null),texelSize:new it(new we)},blending:An,toneMapped:!1,depthWrite:!1,depthTest:!1,fragmentShader:uw,vertexShader:hw})}set inputBuffer(n){this.uniforms.inputBuffer.value=n}setSize(n,e){this.uniforms.texelSize.value.set(1/n,1/e)}},dw=`#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D inputBuffer;uniform mediump sampler2D supportBuffer;
#else
uniform lowp sampler2D inputBuffer;uniform lowp sampler2D supportBuffer;
#endif
uniform float radius;varying vec2 vUv;varying vec2 vUv0;varying vec2 vUv1;varying vec2 vUv2;varying vec2 vUv3;varying vec2 vUv4;varying vec2 vUv5;varying vec2 vUv6;varying vec2 vUv7;void main(){vec4 c=vec4(0.0);c+=texture2D(inputBuffer,vUv0)*0.0625;c+=texture2D(inputBuffer,vUv1)*0.125;c+=texture2D(inputBuffer,vUv2)*0.0625;c+=texture2D(inputBuffer,vUv3)*0.125;c+=texture2D(inputBuffer,vUv)*0.25;c+=texture2D(inputBuffer,vUv4)*0.125;c+=texture2D(inputBuffer,vUv5)*0.0625;c+=texture2D(inputBuffer,vUv6)*0.125;c+=texture2D(inputBuffer,vUv7)*0.0625;vec4 baseColor=texture2D(supportBuffer,vUv);gl_FragColor=mix(baseColor,c,radius);
#include <colorspace_fragment>
}`,pw="uniform vec2 texelSize;varying vec2 vUv;varying vec2 vUv0;varying vec2 vUv1;varying vec2 vUv2;varying vec2 vUv3;varying vec2 vUv4;varying vec2 vUv5;varying vec2 vUv6;varying vec2 vUv7;void main(){vUv=position.xy*0.5+0.5;vUv0=vUv+texelSize*vec2(-1.0,1.0);vUv1=vUv+texelSize*vec2(0.0,1.0);vUv2=vUv+texelSize*vec2(1.0,1.0);vUv3=vUv+texelSize*vec2(-1.0,0.0);vUv4=vUv+texelSize*vec2(1.0,0.0);vUv5=vUv+texelSize*vec2(-1.0,-1.0);vUv6=vUv+texelSize*vec2(0.0,-1.0);vUv7=vUv+texelSize*vec2(1.0,-1.0);gl_Position=vec4(position.xy,1.0,1.0);}",mw=class extends xt{constructor(){super({name:"UpsamplingMaterial",uniforms:{inputBuffer:new it(null),supportBuffer:new it(null),texelSize:new it(new we),radius:new it(.85)},blending:An,toneMapped:!1,depthWrite:!1,depthTest:!1,fragmentShader:dw,vertexShader:pw})}set inputBuffer(n){this.uniforms.inputBuffer.value=n}set supportBuffer(n){this.uniforms.supportBuffer.value=n}get radius(){return this.uniforms.radius.value}set radius(n){this.uniforms.radius.value=n}setSize(n,e){this.uniforms.texelSize.value.set(1/n,1/e)}},gw=class extends ai{constructor(){super("MipmapBlurPass"),this.needsSwap=!1,this.renderTarget=new Sn(1,1,{depthBuffer:!1}),this.renderTarget.texture.name="Upsampling.Mipmap0",this.downsamplingMipmaps=[],this.upsamplingMipmaps=[],this.downsamplingMaterial=new fw,this.upsamplingMaterial=new mw,this.resolution=new we}get texture(){return this.renderTarget.texture}get levels(){return this.downsamplingMipmaps.length}set levels(n){if(this.levels!==n){const e=this.renderTarget;this.dispose(),this.downsamplingMipmaps=[],this.upsamplingMipmaps=[];for(let t=0;t<n;++t){const i=e.clone();i.texture.name="Downsampling.Mipmap"+t,this.downsamplingMipmaps.push(i)}this.upsamplingMipmaps.push(e);for(let t=1,i=n-1;t<i;++t){const r=e.clone();r.texture.name="Upsampling.Mipmap"+t,this.upsamplingMipmaps.push(r)}this.setSize(this.resolution.x,this.resolution.y)}}get radius(){return this.upsamplingMaterial.radius}set radius(n){this.upsamplingMaterial.radius=n}render(n,e,t,i,r){const{scene:s,camera:o}=this,{downsamplingMaterial:a,upsamplingMaterial:l}=this,{downsamplingMipmaps:c,upsamplingMipmaps:u}=this;let h=e;this.fullscreenMaterial=a;for(let f=0,d=c.length;f<d;++f){const v=c[f];a.setSize(h.width,h.height),a.inputBuffer=h.texture,n.setRenderTarget(v),n.render(s,o),h=v}this.fullscreenMaterial=l;for(let f=u.length-1;f>=0;--f){const d=u[f];l.setSize(h.width,h.height),l.inputBuffer=h.texture,l.supportBuffer=c[f].texture,n.setRenderTarget(d),n.render(s,o),h=d}}setSize(n,e){const t=this.resolution;t.set(n,e);let i=t.width,r=t.height;for(let s=0,o=this.downsamplingMipmaps.length;s<o;++s)i=Math.round(i*.5),r=Math.round(r*.5),this.downsamplingMipmaps[s].setSize(i,r),s<this.upsamplingMipmaps.length&&this.upsamplingMipmaps[s].setSize(i,r)}initialize(n,e,t){if(t!==void 0){const i=this.downsamplingMipmaps.concat(this.upsamplingMipmaps);for(const r of i)r.texture.type=t;if(t!==on)this.downsamplingMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1",this.upsamplingMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1";else if(n!==null&&n.outputColorSpace===wt)for(const r of i)r.texture.colorSpace=wt}}dispose(){super.dispose();for(const n of this.downsamplingMipmaps.concat(this.upsamplingMipmaps))n.dispose()}},mo=class extends Wi{constructor(n,e,{attributes:t=vr.NONE,blendFunction:i=Qe.NORMAL,defines:r=new Map,uniforms:s=new Map,extensions:o=null,vertexShader:a=null}={}){super(),this.name=n,this.renderer=null,this.attributes=t,this.fragmentShader=e,this.vertexShader=a,this.defines=r,this.uniforms=s,this.extensions=o,this.blendMode=new tw(i),this.blendMode.addEventListener("change",l=>this.setChanged()),this._inputColorSpace=wi,this._outputColorSpace=oi}get inputColorSpace(){return this._inputColorSpace}set inputColorSpace(n){this._inputColorSpace=n,this.setChanged()}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(n){this._outputColorSpace=n,this.setChanged()}set mainScene(n){}set mainCamera(n){}getName(){return this.name}setRenderer(n){this.renderer=n}getDefines(){return this.defines}getUniforms(){return this.uniforms}getExtensions(){return this.extensions}getBlendMode(){return this.blendMode}getAttributes(){return this.attributes}setAttributes(n){this.attributes=n,this.setChanged()}getFragmentShader(){return this.fragmentShader}setFragmentShader(n){this.fragmentShader=n,this.setChanged()}getVertexShader(){return this.vertexShader}setVertexShader(n){this.vertexShader=n,this.setChanged()}setChanged(){this.dispatchEvent({type:"change"})}setDepthTexture(n,e=ha){}update(n,e,t){}setSize(n,e){}initialize(n,e,t){}dispose(){for(const n of Object.keys(this)){const e=this[n];(e instanceof Sn||e instanceof os||e instanceof sn||e instanceof ai)&&this[n].dispose()}}},vw=`#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D map;
#else
uniform lowp sampler2D map;
#endif
uniform float intensity;void mainImage(const in vec4 inputColor,const in vec2 uv,out vec4 outputColor){vec4 texel=texture2D(map,uv);outputColor=vec4(texel.rgb*intensity,texel.a);}`,_w=class extends mo{constructor({blendFunction:n=Qe.SCREEN,luminanceThreshold:e=.9,luminanceSmoothing:t=.025,mipmapBlur:i=!1,intensity:r=1,radius:s=.85,levels:o=8,kernelSize:a=vf.LARGE,resolutionScale:l=.5,width:c=yi.AUTO_SIZE,height:u=yi.AUTO_SIZE,resolutionX:h=c,resolutionY:f=u}={}){super("BloomEffect",vw,{blendFunction:n,uniforms:new Map([["map",new it(null)],["intensity",new it(r)]])}),this.renderTarget=new Sn(1,1,{depthBuffer:!1}),this.renderTarget.texture.name="Bloom.Target",this.blurPass=new ow({kernelSize:a}),this.luminancePass=new cw({colorOutput:!0}),this.luminanceMaterial.threshold=e,this.luminanceMaterial.smoothing=t,this.mipmapBlurPass=new gw,this.mipmapBlurPass.enabled=i,this.mipmapBlurPass.radius=s,this.mipmapBlurPass.levels=o,this.uniforms.get("map").value=i?this.mipmapBlurPass.texture:this.renderTarget.texture;const d=this.resolution=new yi(this,h,f,l);d.addEventListener("change",v=>this.setSize(d.baseWidth,d.baseHeight))}get texture(){return this.mipmapBlurPass.enabled?this.mipmapBlurPass.texture:this.renderTarget.texture}getTexture(){return this.texture}getResolution(){return this.resolution}getBlurPass(){return this.blurPass}getLuminancePass(){return this.luminancePass}get luminanceMaterial(){return this.luminancePass.fullscreenMaterial}getLuminanceMaterial(){return this.luminancePass.fullscreenMaterial}get width(){return this.resolution.width}set width(n){this.resolution.preferredWidth=n}get height(){return this.resolution.height}set height(n){this.resolution.preferredHeight=n}get dithering(){return this.blurPass.dithering}set dithering(n){this.blurPass.dithering=n}get kernelSize(){return this.blurPass.kernelSize}set kernelSize(n){this.blurPass.kernelSize=n}get distinction(){return console.warn(this.name,"distinction was removed"),1}set distinction(n){console.warn(this.name,"distinction was removed")}get intensity(){return this.uniforms.get("intensity").value}set intensity(n){this.uniforms.get("intensity").value=n}getIntensity(){return this.intensity}setIntensity(n){this.intensity=n}getResolutionScale(){return this.resolution.scale}setResolutionScale(n){this.resolution.scale=n}update(n,e,t){const i=this.renderTarget,r=this.luminancePass;r.enabled?(r.render(n,e),this.mipmapBlurPass.enabled?this.mipmapBlurPass.render(n,r.renderTarget):this.blurPass.render(n,r.renderTarget,i)):this.mipmapBlurPass.enabled?this.mipmapBlurPass.render(n,e):this.blurPass.render(n,e,i)}setSize(n,e){const t=this.resolution;t.setBaseSize(n,e),this.renderTarget.setSize(t.width,t.height),this.blurPass.resolution.copy(t),this.luminancePass.setSize(n,e),this.mipmapBlurPass.setSize(n,e)}initialize(n,e,t){this.blurPass.initialize(n,e,t),this.luminancePass.initialize(n,e,t),this.mipmapBlurPass.initialize(n,e,t),t!==void 0&&(this.renderTarget.texture.type=t,n!==null&&n.outputColorSpace===wt&&(this.renderTarget.texture.colorSpace=wt))}},xw=`#define QUALITY(q) ((q) < 5 ? 1.0 : ((q) > 5 ? ((q) < 10 ? 2.0 : ((q) < 11 ? 4.0 : 8.0)) : 1.5))
#define ONE_OVER_TWELVE 0.08333333333333333
varying vec2 vUvDown;varying vec2 vUvUp;varying vec2 vUvLeft;varying vec2 vUvRight;varying vec2 vUvDownLeft;varying vec2 vUvUpRight;varying vec2 vUvUpLeft;varying vec2 vUvDownRight;vec4 fxaa(const in vec4 inputColor,const in vec2 uv){float lumaCenter=luminance(inputColor.rgb);float lumaDown=luminance(texture2D(inputBuffer,vUvDown).rgb);float lumaUp=luminance(texture2D(inputBuffer,vUvUp).rgb);float lumaLeft=luminance(texture2D(inputBuffer,vUvLeft).rgb);float lumaRight=luminance(texture2D(inputBuffer,vUvRight).rgb);float lumaMin=min(lumaCenter,min(min(lumaDown,lumaUp),min(lumaLeft,lumaRight)));float lumaMax=max(lumaCenter,max(max(lumaDown,lumaUp),max(lumaLeft,lumaRight)));float lumaRange=lumaMax-lumaMin;if(lumaRange<max(EDGE_THRESHOLD_MIN,lumaMax*EDGE_THRESHOLD_MAX)){return inputColor;}float lumaDownLeft=luminance(texture2D(inputBuffer,vUvDownLeft).rgb);float lumaUpRight=luminance(texture2D(inputBuffer,vUvUpRight).rgb);float lumaUpLeft=luminance(texture2D(inputBuffer,vUvUpLeft).rgb);float lumaDownRight=luminance(texture2D(inputBuffer,vUvDownRight).rgb);float lumaDownUp=lumaDown+lumaUp;float lumaLeftRight=lumaLeft+lumaRight;float lumaLeftCorners=lumaDownLeft+lumaUpLeft;float lumaDownCorners=lumaDownLeft+lumaDownRight;float lumaRightCorners=lumaDownRight+lumaUpRight;float lumaUpCorners=lumaUpRight+lumaUpLeft;float edgeHorizontal=(abs(-2.0*lumaLeft+lumaLeftCorners)+abs(-2.0*lumaCenter+lumaDownUp)*2.0+abs(-2.0*lumaRight+lumaRightCorners));float edgeVertical=(abs(-2.0*lumaUp+lumaUpCorners)+abs(-2.0*lumaCenter+lumaLeftRight)*2.0+abs(-2.0*lumaDown+lumaDownCorners));bool isHorizontal=(edgeHorizontal>=edgeVertical);float stepLength=isHorizontal?texelSize.y:texelSize.x;float luma1=isHorizontal?lumaDown:lumaLeft;float luma2=isHorizontal?lumaUp:lumaRight;float gradient1=abs(luma1-lumaCenter);float gradient2=abs(luma2-lumaCenter);bool is1Steepest=gradient1>=gradient2;float gradientScaled=0.25*max(gradient1,gradient2);float lumaLocalAverage=0.0;if(is1Steepest){stepLength=-stepLength;lumaLocalAverage=0.5*(luma1+lumaCenter);}else{lumaLocalAverage=0.5*(luma2+lumaCenter);}vec2 currentUv=uv;if(isHorizontal){currentUv.y+=stepLength*0.5;}else{currentUv.x+=stepLength*0.5;}vec2 offset=isHorizontal?vec2(texelSize.x,0.0):vec2(0.0,texelSize.y);vec2 uv1=currentUv-offset*QUALITY(0);vec2 uv2=currentUv+offset*QUALITY(0);float lumaEnd1=luminance(texture2D(inputBuffer,uv1).rgb);float lumaEnd2=luminance(texture2D(inputBuffer,uv2).rgb);lumaEnd1-=lumaLocalAverage;lumaEnd2-=lumaLocalAverage;bool reached1=abs(lumaEnd1)>=gradientScaled;bool reached2=abs(lumaEnd2)>=gradientScaled;bool reachedBoth=reached1&&reached2;if(!reached1){uv1-=offset*QUALITY(1);}if(!reached2){uv2+=offset*QUALITY(1);}if(!reachedBoth){for(int i=2;i<SAMPLES;++i){if(!reached1){lumaEnd1=luminance(texture2D(inputBuffer,uv1).rgb);lumaEnd1=lumaEnd1-lumaLocalAverage;}if(!reached2){lumaEnd2=luminance(texture2D(inputBuffer,uv2).rgb);lumaEnd2=lumaEnd2-lumaLocalAverage;}reached1=abs(lumaEnd1)>=gradientScaled;reached2=abs(lumaEnd2)>=gradientScaled;reachedBoth=reached1&&reached2;if(!reached1){uv1-=offset*QUALITY(i);}if(!reached2){uv2+=offset*QUALITY(i);}if(reachedBoth){break;}}}float distance1=isHorizontal?(uv.x-uv1.x):(uv.y-uv1.y);float distance2=isHorizontal?(uv2.x-uv.x):(uv2.y-uv.y);bool isDirection1=distance1<distance2;float distanceFinal=min(distance1,distance2);float edgeThickness=(distance1+distance2);bool isLumaCenterSmaller=lumaCenter<lumaLocalAverage;bool correctVariation1=(lumaEnd1<0.0)!=isLumaCenterSmaller;bool correctVariation2=(lumaEnd2<0.0)!=isLumaCenterSmaller;bool correctVariation=isDirection1?correctVariation1:correctVariation2;float pixelOffset=-distanceFinal/edgeThickness+0.5;float finalOffset=correctVariation?pixelOffset:0.0;float lumaAverage=ONE_OVER_TWELVE*(2.0*(lumaDownUp+lumaLeftRight)+lumaLeftCorners+lumaRightCorners);float subPixelOffset1=clamp(abs(lumaAverage-lumaCenter)/lumaRange,0.0,1.0);float subPixelOffset2=(-2.0*subPixelOffset1+3.0)*subPixelOffset1*subPixelOffset1;float subPixelOffsetFinal=subPixelOffset2*subPixelOffset2*SUBPIXEL_QUALITY;finalOffset=max(finalOffset,subPixelOffsetFinal);vec2 finalUv=uv;if(isHorizontal){finalUv.y+=finalOffset*stepLength;}else{finalUv.x+=finalOffset*stepLength;}return texture2D(inputBuffer,finalUv);}void mainImage(const in vec4 inputColor,const in vec2 uv,out vec4 outputColor){outputColor=fxaa(inputColor,uv);}`,yw="varying vec2 vUvDown;varying vec2 vUvUp;varying vec2 vUvLeft;varying vec2 vUvRight;varying vec2 vUvDownLeft;varying vec2 vUvUpRight;varying vec2 vUvUpLeft;varying vec2 vUvDownRight;void mainSupport(const in vec2 uv){vUvDown=uv+vec2(0.0,-1.0)*texelSize;vUvUp=uv+vec2(0.0,1.0)*texelSize;vUvRight=uv+vec2(1.0,0.0)*texelSize;vUvLeft=uv+vec2(-1.0,0.0)*texelSize;vUvDownLeft=uv+vec2(-1.0,-1.0)*texelSize;vUvUpRight=uv+vec2(1.0,1.0)*texelSize;vUvUpLeft=uv+vec2(-1.0,1.0)*texelSize;vUvDownRight=uv+vec2(1.0,-1.0)*texelSize;}",Sw=class extends mo{constructor({blendFunction:n=Qe.SRC}={}){super("FXAAEffect",xw,{vertexShader:yw,blendFunction:n,defines:new Map([["EDGE_THRESHOLD_MIN","0.0312"],["EDGE_THRESHOLD_MAX","0.125"],["SUBPIXEL_QUALITY","0.75"],["SAMPLES","12"]])})}get minEdgeThreshold(){return Number(this.defines.get("EDGE_THRESHOLD_MIN"))}set minEdgeThreshold(n){this.defines.set("EDGE_THRESHOLD_MIN",n.toFixed(12)),this.setChanged()}get maxEdgeThreshold(){return Number(this.defines.get("EDGE_THRESHOLD_MAX"))}set maxEdgeThreshold(n){this.defines.set("EDGE_THRESHOLD_MAX",n.toFixed(12)),this.setChanged()}get subpixelQuality(){return Number(this.defines.get("SUBPIXEL_QUALITY"))}set subpixelQuality(n){this.defines.set("SUBPIXEL_QUALITY",n.toFixed(12)),this.setChanged()}get samples(){return Number(this.defines.get("SAMPLES"))}set samples(n){this.defines.set("SAMPLES",n.toFixed(0)),this.setChanged()}},a0=class extends ai{constructor(n,e,t=null){super("RenderPass",n,e),this.needsSwap=!1,this.clearPass=new Tm,this.overrideMaterialManager=t===null?null:new o0(t),this.ignoreBackground=!1,this.skipShadowMapUpdate=!1,this.selection=null}set mainScene(n){this.scene=n}set mainCamera(n){this.camera=n}get renderToScreen(){return super.renderToScreen}set renderToScreen(n){super.renderToScreen=n,this.clearPass.renderToScreen=n}get overrideMaterial(){const n=this.overrideMaterialManager;return n!==null?n.material:null}set overrideMaterial(n){const e=this.overrideMaterialManager;n!==null?e!==null?e.setMaterial(n):this.overrideMaterialManager=new o0(n):e!==null&&(e.dispose(),this.overrideMaterialManager=null)}getOverrideMaterial(){return this.overrideMaterial}setOverrideMaterial(n){this.overrideMaterial=n}get clear(){return this.clearPass.enabled}set clear(n){this.clearPass.enabled=n}getSelection(){return this.selection}setSelection(n){this.selection=n}isBackgroundDisabled(){return this.ignoreBackground}setBackgroundDisabled(n){this.ignoreBackground=n}isShadowMapDisabled(){return this.skipShadowMapUpdate}setShadowMapDisabled(n){this.skipShadowMapUpdate=n}getClearPass(){return this.clearPass}render(n,e,t,i,r){const s=this.scene,o=this.camera,a=this.selection,l=o.layers.mask,c=s.background,u=n.shadowMap.autoUpdate,h=this.renderToScreen?null:e;a!==null&&o.layers.set(a.getLayer()),this.skipShadowMapUpdate&&(n.shadowMap.autoUpdate=!1),(this.ignoreBackground||this.clearPass.overrideClearColor!==null)&&(s.background=null),this.clearPass.enabled&&this.clearPass.render(n,e),n.setRenderTarget(h),this.overrideMaterialManager!==null?this.overrideMaterialManager.render(n,s,o):n.render(s,o),o.layers.mask=l,s.background=c,n.shadowMap.autoUpdate=u}},Po={DEFAULT:0,ESKIL:1},Mw=`void mainImage(const in vec4 inputColor,const in vec2 uv,out vec4 outputColor){vec3 noise=vec3(rand(uv*(1.0+time)));
#ifdef PREMULTIPLY
outputColor=vec4(min(inputColor.rgb*noise,vec3(1.0)),inputColor.a);
#else
outputColor=vec4(noise,inputColor.a);
#endif
}`,bw=class extends mo{constructor({blendFunction:n=Qe.SCREEN,premultiply:e=!1}={}){super("NoiseEffect",Mw,{blendFunction:n}),this.premultiply=e}get premultiply(){return this.defines.has("PREMULTIPLY")}set premultiply(n){this.premultiply!==n&&(n?this.defines.set("PREMULTIPLY","1"):this.defines.delete("PREMULTIPLY"),this.setChanged())}isPremultiplied(){return this.premultiply}setPremultiplied(n){this.premultiply=n}},ww=`uniform float offset;uniform float darkness;void mainImage(const in vec4 inputColor,const in vec2 uv,out vec4 outputColor){const vec2 center=vec2(0.5);vec3 color=inputColor.rgb;
#if VIGNETTE_TECHNIQUE == 0
float d=distance(uv,center);color*=smoothstep(0.8,offset*0.799,d*(darkness+offset));
#else
vec2 coord=(uv-center)*vec2(offset);color=mix(color,vec3(1.0-darkness),dot(coord,coord));
#endif
outputColor=vec4(color,inputColor.a);}`,Ew=class extends mo{constructor({blendFunction:n,eskil:e=!1,technique:t=e?Po.ESKIL:Po.DEFAULT,offset:i=.5,darkness:r=.5}={}){super("VignetteEffect",ww,{blendFunction:n,defines:new Map([["VIGNETTE_TECHNIQUE",t.toFixed(0)]]),uniforms:new Map([["offset",new it(i)],["darkness",new it(r)]])})}get technique(){return Number(this.defines.get("VIGNETTE_TECHNIQUE"))}set technique(n){this.technique!==n&&(this.defines.set("VIGNETTE_TECHNIQUE",n.toFixed(0)),this.setChanged())}get eskil(){return this.technique===Po.ESKIL}set eskil(n){this.technique=n?Po.ESKIL:Po.DEFAULT}getTechnique(){return this.technique}setTechnique(n){this.technique=n}get offset(){return this.uniforms.get("offset").value}set offset(n){this.uniforms.get("offset").value=n}getOffset(){return this.offset}setOffset(n){this.offset=n}get darkness(){return this.uniforms.get("darkness").value}set darkness(n){this.uniforms.get("darkness").value=n}getDarkness(){return this.darkness}setDarkness(n){this.darkness=n}},Tw=`#include <common>
#include <packing>
#include <dithering_pars_fragment>
#define packFloatToRGBA(v) packDepthToRGBA(v)
#define unpackRGBAToFloat(v) unpackRGBAToDepth(v)
#ifdef FRAMEBUFFER_PRECISION_HIGH
uniform mediump sampler2D inputBuffer;
#else
uniform lowp sampler2D inputBuffer;
#endif
#if DEPTH_PACKING == 3201
uniform lowp sampler2D depthBuffer;
#elif defined(GL_FRAGMENT_PRECISION_HIGH)
uniform highp sampler2D depthBuffer;
#else
uniform mediump sampler2D depthBuffer;
#endif
uniform vec2 resolution;uniform vec2 texelSize;uniform float cameraNear;uniform float cameraFar;uniform float aspect;uniform float time;varying vec2 vUv;vec4 sRGBToLinear(const in vec4 value){return vec4(mix(pow(value.rgb*0.9478672986+vec3(0.0521327014),vec3(2.4)),value.rgb*0.0773993808,vec3(lessThanEqual(value.rgb,vec3(0.04045)))),value.a);}float readDepth(const in vec2 uv){
#if DEPTH_PACKING == 3201
return unpackRGBAToDepth(texture2D(depthBuffer,uv));
#else
return texture2D(depthBuffer,uv).r;
#endif
}float getViewZ(const in float depth){
#ifdef PERSPECTIVE_CAMERA
return perspectiveDepthToViewZ(depth,cameraNear,cameraFar);
#else
return orthographicDepthToViewZ(depth,cameraNear,cameraFar);
#endif
}vec3 RGBToHCV(const in vec3 RGB){vec4 P=mix(vec4(RGB.bg,-1.0,2.0/3.0),vec4(RGB.gb,0.0,-1.0/3.0),step(RGB.b,RGB.g));vec4 Q=mix(vec4(P.xyw,RGB.r),vec4(RGB.r,P.yzx),step(P.x,RGB.r));float C=Q.x-min(Q.w,Q.y);float H=abs((Q.w-Q.y)/(6.0*C+EPSILON)+Q.z);return vec3(H,C,Q.x);}vec3 RGBToHSL(const in vec3 RGB){vec3 HCV=RGBToHCV(RGB);float L=HCV.z-HCV.y*0.5;float S=HCV.y/(1.0-abs(L*2.0-1.0)+EPSILON);return vec3(HCV.x,S,L);}vec3 HueToRGB(const in float H){float R=abs(H*6.0-3.0)-1.0;float G=2.0-abs(H*6.0-2.0);float B=2.0-abs(H*6.0-4.0);return clamp(vec3(R,G,B),0.0,1.0);}vec3 HSLToRGB(const in vec3 HSL){vec3 RGB=HueToRGB(HSL.x);float C=(1.0-abs(2.0*HSL.z-1.0))*HSL.y;return(RGB-0.5)*C+HSL.z;}FRAGMENT_HEAD void main(){FRAGMENT_MAIN_UV vec4 color0=texture2D(inputBuffer,UV);vec4 color1=vec4(0.0);FRAGMENT_MAIN_IMAGE color0.a=clamp(color0.a,0.0,1.0);gl_FragColor=color0;
#ifdef ENCODE_OUTPUT
#include <colorspace_fragment>
#endif
#include <dithering_fragment>
}`,Aw="uniform vec2 resolution;uniform vec2 texelSize;uniform float cameraNear;uniform float cameraFar;uniform float aspect;uniform float time;varying vec2 vUv;VERTEX_HEAD void main(){vUv=position.xy*0.5+0.5;VERTEX_MAIN_SUPPORT gl_Position=vec4(position.xy,1.0,1.0);}",Cw=class extends xt{constructor(n,e,t,i,r=!1){super({name:"EffectMaterial",defines:{THREE_REVISION:ua.replace(/\D+/g,""),DEPTH_PACKING:"0",ENCODE_OUTPUT:"1"},uniforms:{inputBuffer:new it(null),depthBuffer:new it(null),resolution:new it(new we),texelSize:new it(new we),cameraNear:new it(.3),cameraFar:new it(1e3),aspect:new it(1),time:new it(0)},blending:An,toneMapped:!1,depthWrite:!1,depthTest:!1,dithering:r}),n&&this.setShaderParts(n),e&&this.setDefines(e),t&&this.setUniforms(t),this.copyCameraSettings(i)}set inputBuffer(n){this.uniforms.inputBuffer.value=n}setInputBuffer(n){this.uniforms.inputBuffer.value=n}get depthBuffer(){return this.uniforms.depthBuffer.value}set depthBuffer(n){this.uniforms.depthBuffer.value=n}get depthPacking(){return Number(this.defines.DEPTH_PACKING)}set depthPacking(n){this.defines.DEPTH_PACKING=n.toFixed(0),this.needsUpdate=!0}setDepthBuffer(n,e=ha){this.depthBuffer=n,this.depthPacking=e}setShaderData(n){this.setShaderParts(n.shaderParts),this.setDefines(n.defines),this.setUniforms(n.uniforms),this.setExtensions(n.extensions)}setShaderParts(n){return this.fragmentShader=Tw.replace(ft.FRAGMENT_HEAD,n.get(ft.FRAGMENT_HEAD)||"").replace(ft.FRAGMENT_MAIN_UV,n.get(ft.FRAGMENT_MAIN_UV)||"").replace(ft.FRAGMENT_MAIN_IMAGE,n.get(ft.FRAGMENT_MAIN_IMAGE)||""),this.vertexShader=Aw.replace(ft.VERTEX_HEAD,n.get(ft.VERTEX_HEAD)||"").replace(ft.VERTEX_MAIN_SUPPORT,n.get(ft.VERTEX_MAIN_SUPPORT)||""),this.needsUpdate=!0,this}setDefines(n){for(const e of n.entries())this.defines[e[0]]=e[1];return this.needsUpdate=!0,this}setUniforms(n){for(const e of n.entries())this.uniforms[e[0]]=e[1];return this}setExtensions(n){this.extensions={};for(const e of n)this.extensions[e]=!0;return this}get encodeOutput(){return this.defines.ENCODE_OUTPUT!==void 0}set encodeOutput(n){this.encodeOutput!==n&&(n?this.defines.ENCODE_OUTPUT="1":delete this.defines.ENCODE_OUTPUT,this.needsUpdate=!0)}isOutputEncodingEnabled(n){return this.encodeOutput}setOutputEncodingEnabled(n){this.encodeOutput=n}get time(){return this.uniforms.time.value}set time(n){this.uniforms.time.value=n}setDeltaTime(n){this.uniforms.time.value+=n}adoptCameraSettings(n){this.copyCameraSettings(n)}copyCameraSettings(n){n&&(this.uniforms.cameraNear.value=n.near,this.uniforms.cameraFar.value=n.far,n instanceof kn?this.defines.PERSPECTIVE_CAMERA="1":delete this.defines.PERSPECTIVE_CAMERA,this.needsUpdate=!0)}setSize(n,e){const t=this.uniforms;t.resolution.value.set(n,e),t.texelSize.value.set(1/n,1/e),t.aspect.value=n/e}static get Section(){return ft}};function l0(n,e,t){for(const i of e){const r="$1"+n+i.charAt(0).toUpperCase()+i.slice(1),s=new RegExp("([^\\.])(\\b"+i+"\\b)","g");for(const o of t.entries())o[1]!==null&&t.set(o[0],o[1].replace(s,r))}}function Rw(n,e,t){let i=e.getFragmentShader(),r=e.getVertexShader();const s=i!==void 0&&/mainImage/.test(i),o=i!==void 0&&/mainUv/.test(i);if(t.attributes|=e.getAttributes(),i===void 0)throw new Error(`Missing fragment shader (${e.name})`);if(o&&t.attributes&vr.CONVOLUTION)throw new Error(`Effects that transform UVs are incompatible with convolution effects (${e.name})`);if(!s&&!o)throw new Error(`Could not find mainImage or mainUv function (${e.name})`);{const a=/\w+\s+(\w+)\([\w\s,]*\)\s*{/g,l=t.shaderParts;let c=l.get(ft.FRAGMENT_HEAD)||"",u=l.get(ft.FRAGMENT_MAIN_UV)||"",h=l.get(ft.FRAGMENT_MAIN_IMAGE)||"",f=l.get(ft.VERTEX_HEAD)||"",d=l.get(ft.VERTEX_MAIN_SUPPORT)||"";const v=new Set,g=new Set;if(o&&(u+=`	${n}MainUv(UV);
`,t.uvTransformation=!0),r!==null&&/mainSupport/.test(r)){const x=/mainSupport *\([\w\s]*?uv\s*?\)/.test(r);d+=`	${n}MainSupport(`,d+=x?`vUv);
`:`);
`;for(const _ of r.matchAll(/(?:varying\s+\w+\s+([\S\s]*?);)/g))for(const y of _[1].split(/\s*,\s*/))t.varyings.add(y),v.add(y),g.add(y);for(const _ of r.matchAll(a))g.add(_[1])}for(const x of i.matchAll(a))g.add(x[1]);for(const x of e.defines.keys())g.add(x.replace(/\([\w\s,]*\)/g,""));for(const x of e.uniforms.keys())g.add(x);g.delete("while"),g.delete("for"),g.delete("if"),e.uniforms.forEach((x,_)=>t.uniforms.set(n+_.charAt(0).toUpperCase()+_.slice(1),x)),e.defines.forEach((x,_)=>t.defines.set(n+_.charAt(0).toUpperCase()+_.slice(1),x));const p=new Map([["fragment",i],["vertex",r]]);l0(n,g,t.defines),l0(n,g,p),i=p.get("fragment"),r=p.get("vertex");const m=e.blendMode;if(t.blendModes.set(m.blendFunction,m),s){e.inputColorSpace!==null&&e.inputColorSpace!==t.colorSpace&&(h+=e.inputColorSpace===wt?`color0 = sRGBTransferOETF(color0);
	`:`color0 = sRGBToLinear(color0);
	`),e.outputColorSpace!==oi?t.colorSpace=e.outputColorSpace:e.inputColorSpace!==null&&(t.colorSpace=e.inputColorSpace);const x=/MainImage *\([\w\s,]*?depth[\w\s,]*?\)/;h+=`${n}MainImage(color0, UV, `,t.attributes&vr.DEPTH&&x.test(i)&&(h+="depth, ",t.readDepth=!0),h+=`color1);
	`;const _=n+"BlendOpacity";t.uniforms.set(_,m.opacity),h+=`color0 = blend${m.blendFunction}(color0, color1, ${_});

	`,c+=`uniform float ${_};

`}if(c+=i+`
`,r!==null&&(f+=r+`
`),l.set(ft.FRAGMENT_HEAD,c),l.set(ft.FRAGMENT_MAIN_UV,u),l.set(ft.FRAGMENT_MAIN_IMAGE,h),l.set(ft.VERTEX_HEAD,f),l.set(ft.VERTEX_MAIN_SUPPORT,d),e.extensions!==null)for(const x of e.extensions)t.extensions.add(x)}}var ru=class extends ai{constructor(n,...e){super("EffectPass"),this.fullscreenMaterial=new Cw(null,null,null,n),this.listener=t=>this.handleEvent(t),this.effects=[],this.setEffects(e),this.skipRendering=!1,this.minTime=1,this.maxTime=Number.POSITIVE_INFINITY,this.timeScale=1}set mainScene(n){for(const e of this.effects)e.mainScene=n}set mainCamera(n){this.fullscreenMaterial.copyCameraSettings(n);for(const e of this.effects)e.mainCamera=n}get encodeOutput(){return this.fullscreenMaterial.encodeOutput}set encodeOutput(n){this.fullscreenMaterial.encodeOutput=n}get dithering(){return this.fullscreenMaterial.dithering}set dithering(n){const e=this.fullscreenMaterial;e.dithering=n,e.needsUpdate=!0}setEffects(n){for(const e of this.effects)e.removeEventListener("change",this.listener);this.effects=n.sort((e,t)=>t.attributes-e.attributes);for(const e of this.effects)e.addEventListener("change",this.listener)}updateMaterial(){const n=new xb;let e=0;for(const o of this.effects)if(o.blendMode.blendFunction===Qe.DST)n.attributes|=o.getAttributes()&vr.DEPTH;else{if(n.attributes&o.getAttributes()&vr.CONVOLUTION)throw new Error(`Convolution effects cannot be merged (${o.name})`);Rw("e"+e++,o,n)}let t=n.shaderParts.get(ft.FRAGMENT_HEAD),i=n.shaderParts.get(ft.FRAGMENT_MAIN_IMAGE),r=n.shaderParts.get(ft.FRAGMENT_MAIN_UV);const s=/\bblend\b/g;for(const o of n.blendModes.values())t+=o.getShaderCode().replace(s,`blend${o.blendFunction}`)+`
`;n.attributes&vr.DEPTH?(n.readDepth&&(i=`float depth = readDepth(UV);

	`+i),this.needsDepthTexture=this.getDepthTexture()===null):this.needsDepthTexture=!1,n.colorSpace===wt&&(i+=`color0 = sRGBToLinear(color0);
	`),n.uvTransformation?(r=`vec2 transformedUv = vUv;
`+r,n.defines.set("UV","transformedUv")):n.defines.set("UV","vUv"),n.shaderParts.set(ft.FRAGMENT_HEAD,t),n.shaderParts.set(ft.FRAGMENT_MAIN_IMAGE,i),n.shaderParts.set(ft.FRAGMENT_MAIN_UV,r);for(const[o,a]of n.shaderParts)a!==null&&n.shaderParts.set(o,a.trim().replace(/^#/,`
#`));this.skipRendering=e===0,this.needsSwap=!this.skipRendering,this.fullscreenMaterial.setShaderData(n)}recompile(){this.updateMaterial()}getDepthTexture(){return this.fullscreenMaterial.depthBuffer}setDepthTexture(n,e=ha){this.fullscreenMaterial.depthBuffer=n,this.fullscreenMaterial.depthPacking=e;for(const t of this.effects)t.setDepthTexture(n,e)}render(n,e,t,i,r){for(const s of this.effects)s.update(n,e,i);if(!this.skipRendering||this.renderToScreen){const s=this.fullscreenMaterial;s.inputBuffer=e.texture,s.time+=i*this.timeScale,n.setRenderTarget(this.renderToScreen?null:t),n.render(this.scene,this.camera)}}setSize(n,e){this.fullscreenMaterial.setSize(n,e);for(const t of this.effects)t.setSize(n,e)}initialize(n,e,t){this.renderer=n;for(const i of this.effects)i.initialize(n,e,t);this.updateMaterial(),t!==void 0&&t!==on&&(this.fullscreenMaterial.defines.FRAMEBUFFER_PRECISION_HIGH="1")}dispose(){super.dispose();for(const n of this.effects)n.removeEventListener("change",this.listener),n.dispose()}handleEvent(n){switch(n.type){case"change":this.recompile();break}}};class Pw extends mo{constructor(){super("GradeEffect",`
      uniform float uExposure; uniform float uContrast; uniform float uSaturation; uniform float uGrad;
      uniform vec3 uLift; uniform vec3 uGain;
      vec3 agxCurve(vec3 x) {
        vec3 x2 = x * x; vec3 x4 = x2 * x2;
        return 15.5 * x4 * x2 - 40.14 * x4 * x + 31.96 * x4 - 6.868 * x2 * x + 0.4298 * x2 + 0.1191 * x - 0.00232;
      }
      vec3 agx(vec3 c) {
        const mat3 inset = mat3(
          vec3(0.856627153315983, 0.137318972929847, 0.11189821299995),
          vec3(0.0951212405381588, 0.761241990602591, 0.0767994186031903),
          vec3(0.0482516061458583, 0.101439036467562, 0.811302368396859));
        const mat3 outset = mat3(
          vec3(1.1271005818144368, -0.1413297634984383, -0.14132976349843826),
          vec3(-0.11060664309660323, 1.157823702216272, -0.11060664309660294),
          vec3(-0.016493938717834573, -0.016493938717834257, 1.2519364065950405));
        c = inset * c;
        c = clamp((log2(max(c, 1e-10)) + 12.47393) / 16.5, 0.0, 1.0);
        c = agxCurve(c);
        c = outset * c;
        return clamp(c, 0.0, 1.0); // perceptual (gamma ~2.2) domain
      }
      void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
        float grad = mix(1.0 - uGrad, 1.0, smoothstep(0.0, 0.42, uv.y));
        vec3 g = agx(inputColor.rgb * uExposure * grad);
        g = g * uGain + uLift * (1.0 - g);
        g = (g - 0.5) * uContrast + 0.5;
        float l = dot(g, vec3(0.2126, 0.7152, 0.0722));
        g = mix(vec3(l), g, uSaturation);
        g = clamp(g, 0.0, 1.0);
        outputColor = vec4(pow(g, vec3(2.2)), inputColor.a);
      }`,{blendFunction:Qe.SRC,uniforms:new Map([["uExposure",new it(1)],["uContrast",new it(1)],["uSaturation",new it(1)],["uGrad",new it(.5)],["uLift",new it(new O)],["uGain",new it(new O(1,1,1))]])})}}class Lw extends mo{constructor(e){super("SoftenEffect",`
      uniform float uAmount;
      void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
        vec3 acc = inputColor.rgb;
        float rad = uAmount * 11.0;
        float jit = fract(sin(dot(uv * resolution, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
        for (int i = 0; i < TAPS; i++) {
          float fi = float(i);
          float a = fi * 2.39996 + jit;
          float d = sqrt((fi + 0.5) / float(TAPS)) * rad;
          acc += texture2D(inputBuffer, uv + vec2(cos(a), sin(a)) * d * texelSize).rgb;
        }
        vec3 c = acc / float(TAPS + 1);
        float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = mix(c, vec3(l), uAmount * 0.35) * (1.0 - uAmount * 0.5);
        outputColor = vec4(c, inputColor.a);
      }`,{attributes:vr.CONVOLUTION,blendFunction:Qe.SRC,defines:new Map([["TAPS",String(e)]]),uniforms:new Map([["uAmount",new it(0)]])})}}function Dw({renderer:n,scene:e,camera:t,Q:i}){const r=new _b(n,{frameBufferType:ho,multisampling:i.msaa}),s=new a0(e,t),o=new Lw(i.softenTaps),a=new ru(t,o);a.enabled=!1;const l=new a0(e,t);l.clearPass.setClearFlags(!1,!0,!1),l.selection=new Sb(void 0,gl),l.enabled=!1;const c=new _w({blendFunction:Qe.ADD,mipmapBlur:!0,intensity:.8,luminanceThreshold:.65,luminanceSmoothing:.35,radius:.78,levels:i.bloomLevels,resolutionScale:i.bloomScale}),u=new Pw,h=new Ew({offset:.3,darkness:.6}),f=new ru(t,c,u,h),d=new Sw,v=new bw({blendFunction:Qe.OVERLAY,premultiply:!1});v.blendMode.opacity.value=.075;const g=new ru(t,d,v);g.dithering=!0,r.addPass(s),r.addPass(a),r.addPass(l),r.addPass(f),r.addPass(g),d.blendMode.opacity.value=i.fxaa?1:0;const p=u.uniforms;return{composer:r,setGrade(m,x=1){p.get("uExposure").value=m.exposure*x,p.get("uContrast").value=m.contrast,p.get("uSaturation").value=m.saturation,p.get("uGrad").value=m.grad,p.get("uLift").value.copy(m.lift),p.get("uGain").value.copy(m.gain),c.intensity=m.bloom,c.luminanceMaterial.threshold=m.threshold,h.darkness=m.vignette},setSoften(m){const x=m>.002;return o.uniforms.get("uAmount").value=m,a.enabled=x,l.enabled=x,x},setQuality(m){r.multisampling=m.msaa,d.blendMode.opacity.value=m.fxaa?1:0,o.defines.set("TAPS",String(m.softenTaps)),o.setChanged(),c.resolution.scale=m.bloomScale,c.mipmapBlurPass.levels=m.bloomLevels},dispose(){r.dispose()}}}const Lo=[{pos:[0,1.05,12.2],tgt:[0,2.15,0]},{pos:[-1.9,1.3,11.7],tgt:[.2,2.2,-.4]},{pos:[1.55,.85,12.9],tgt:[-.15,2.25,0]},{pos:[-1,1.5,10.9],tgt:[.1,2.3,0]},{pos:[2,1.15,11.5],tgt:[-.2,2.1,0]},{pos:[0,.78,13.3],tgt:[0,2.28,0]}],Ps={pos:[0,7,25],tgt:[0,9.8,-18]},c0={pos:[0,.4,1.3],tgt:[0,-.12,0]},u0={pos:[0,.15,-1.6],tgt:[0,.18,0]},Iw=n=>n<.5?4*n*n*n:1-Math.pow(-2*n+2,3)/2,Uw=n=>1-Math.pow(1-n,3);function Nw(n,{reducedMotion:e=!1}={}){const t={pos:new O,tgt:new O},i={pos:new O,tgt:new O},r={pos:new O,tgt:new O},s={x:0,y:0,sx:0,sy:0},o=e?0:1;function a(c,u){const h=Lo.length,f=(c%h+h)%h,d=Math.floor(f),v=(d+1)%h,g=f-d;return i.pos.fromArray(Lo[d].pos),i.tgt.fromArray(Lo[d].tgt),r.pos.fromArray(Lo[v].pos),r.tgt.fromArray(Lo[v].tgt),u.pos.lerpVectors(i.pos,r.pos,g),u.tgt.lerpVectors(i.tgt,r.tgt,g),u}const l=new O;return{setPointer(c,u){s.x=c,s.y=u},update(c,u,h,f){a(h.pose,t);const d=bh(1.25,.55,f);n.fov=er(37,55,d);const v=er(1,1.3,d);if(t.pos.sub(t.tgt).multiplyScalar(v).add(t.tgt),t.pos.y+=d*.25,t.pos.addScaledVector(l.fromArray(c0.pos),h.timeline*o),t.tgt.addScaledVector(l.fromArray(c0.tgt),h.timeline*o),t.pos.addScaledVector(l.fromArray(u0.pos),h.explore*o),t.tgt.addScaledVector(l.fromArray(u0.tgt),h.explore*o),h.enter<1&&o){const m=h.enter,x=Uw(m),_=Iw(m);t.pos.set(er(Ps.pos[0],t.pos.x,_),er(Ps.pos[1],t.pos.y,_),er(Ps.pos[2],t.pos.z,x)),t.tgt.set(er(Ps.tgt[0],t.tgt.x,_),er(Ps.tgt[1],t.tgt.y,_),er(Ps.tgt[2],t.tgt.z,x))}const g=1-Math.exp(-c*2.2);s.sx+=(s.x-s.sx)*g,s.sy+=(s.y-s.sy)*g;const p=e?.3:1;t.pos.x+=Math.sin(u*.23)*.06*o+s.sx*.55*p,t.pos.y+=Math.sin(u*.31+1)*.04*o+s.sy*.22*p,t.pos.z+=Math.sin(u*.17+2)*.07*o,t.tgt.x+=Math.sin(u*.19)*.03*o+s.sx*.12*p,t.tgt.y+=Math.sin(u*.27)*.02*o+s.sy*.06*p,n.position.copy(t.pos),n.lookAt(t.tgt),o&&n.rotateZ(Math.sin(u*.13)*.0025),n.updateProjectionMatrix()}}}const Ja={high:{legSegs:84,legRadial:20,roots:120,rootSegs:22,rootRadial:6,sideTrunks:16,buttressRows:3,neems:3,neemDensity:1,canopyKeep:1,ceiling:90,treeline:70,shrubs:17,grass:110,beams:8,mistStride:1,dust:3200,groundRadial:160,kundSegs:160,msaa:0,fxaa:!0,bloomScale:.5,bloomLevels:8,softenTaps:10},mid:{legSegs:56,legRadial:14,roots:70,rootSegs:16,rootRadial:5,sideTrunks:12,buttressRows:2,neems:3,neemDensity:.75,canopyKeep:.75,ceiling:60,treeline:45,shrubs:14,grass:70,beams:6,mistStride:2,dust:1800,groundRadial:112,kundSegs:112,msaa:0,fxaa:!0,bloomScale:.42,bloomLevels:7,softenTaps:8},low:{legSegs:34,legRadial:9,roots:32,rootSegs:11,rootRadial:4,sideTrunks:8,buttressRows:1,neems:2,neemDensity:.55,canopyKeep:.5,ceiling:32,treeline:26,shrubs:10,grass:36,beams:4,mistStride:3,dust:800,groundRadial:72,kundSegs:72,msaa:0,fxaa:!0,bloomScale:.35,bloomLevels:5,softenTaps:6}},fr=_l.length,su=(n,e)=>e+((n-e)%fr+fr*1.5)%fr-fr/2;function Fw({renderer:n,scene:e,camera:t,bus:i,quality:r="high",intro:s=!0}={}){const o=typeof matchMedia=="function"&&matchMedia("(prefers-reduced-motion: reduce)").matches;let a=Ja[r]?r:"high",l=Ja[a];const c=zM(),u=XM(c);u.uHoloPos.value.fromArray(HM);const h=new Zn;h.name="world",e.add(h);const f=new yn;f.name="hologramAnchor",f.position.fromArray(jr),e.add(f),t.near=.2,t.far=1500,t.fov=37,t.layers.enable(gl);const d=YM(u);h.add(d.mesh);let v=null;function g(){const W=jM(u,l),re=eb(u,l),Ae=rb(u,l),ee=sb(u,l,Ae),F=ob(u,l),xe=ub(u,l);h.add(W.mesh,re.group,Ae.mesh,ee.mesh,F.mesh,xe.group),u.uBeams.value.forEach((G,he)=>{G.w=he<F.count?Nl[he][3]:0}),v={ground:W,kund:re,banyan:Ae,foliage:ee,beams:F,atmo:xe},S()}function p(){if(!v)return;const{ground:W,kund:re,banyan:Ae,foliage:ee,beams:F,atmo:xe}=v;h.remove(W.mesh,re.group,Ae.mesh,ee.mesh,F.mesh,xe.group);for(const G of Object.values(v))G.dispose();v=null}const m=Dw({renderer:n,scene:e,camera:t,Q:l}),x=Nw(t,{reducedMotion:o}),_=$M(),y={mood:0,pose:0,enter:s?0:1,timeline:0,explore:0,dim:0},C={explore:!1,menu:!1};let M=t.aspect||16/10,w={w:1440,h:900},P=!1,I=1/60;function S(){if(!v)return;const W=w.h*n.getPixelRatio()/(2*Math.tan(Bi.degToRad(t.fov)/2));v.kund.setPixelScale(W),v.atmo.setPixelScale(W)}function b(W){const re=u;re.uSkyTop.value.copy(W.skyTop),re.uSkyHorizon.value.copy(W.skyHorizon),re.uSkyGain.value=W.skyGain,re.uCloudLit.value.copy(W.cloudLit),re.uCloudShadow.value.copy(W.cloudShadow),re.uCloudCover.value=W.cloudCover,re.uCloudSharp.value=W.cloudSharp,re.uSunDir.value.copy(W.sunDir),re.uSunColor.value.copy(W.sunColor),re.uSunGlow.value=W.sunGlow,re.uMoon.value=W.moon,re.uStars.value=W.stars,re.uFogColor.value.copy(W.fogColor),re.uFogDensity.value=W.fogDensity,re.uFogStart.value=W.fogStart,re.uFogHeight.value=W.fogHeight,re.uMist.value=W.mist,re.uAmbSky.value.copy(W.ambSky),re.uAmbGround.value.copy(W.ambGround),re.uKeyColor.value.copy(W.keyColor),re.uKeyStrength.value=W.keyStrength,re.uRimColor.value.copy(W.rim),re.uBark.value.copy(W.bark),re.uLeaf.value.copy(W.leaf),re.uGround.value.copy(W.ground),re.uStone.value.copy(W.stone),re.uBeamDir.value.copy(W.beamDir),re.uBeamColor.value.copy(W.beamColor),re.uBeamStrength.value=W.beamStrength,re.uHoloLight.value=W.holoLight,re.uNight.value=W.night}g(),Qd(_,0),b(_);function N(W,{duration:re}={}){const Ae=(Math.round(W)%fr+fr)%fr;if(Fn.killTweensOf(y,"pose,mood"),y.mood=su(y.mood,Ae),o){y.pose=Ae,Fn.to(y,{mood:Ae,duration:re??.8,ease:"power2.inOut"});return}y.pose=su(y.pose,Ae),Fn.to(y,{pose:Ae,mood:Ae,duration:re??2.6,ease:"power2.inOut"})}function R(W,{duration:re=.6}={}){const Ae=Bi.clamp(W,0,1)*(fr-1);Fn.killTweensOf(y,"pose,mood"),y.mood=Ae,y.pose=su(y.pose,Ae),Fn.to(y,{pose:Ae,duration:re,ease:"power2.out"})}function H(W){!Ja[W]||W===a||(a=W,l=Ja[W],p(),g(),m.setQuality(l),K(w.w,w.h))}function T(){const W=C.menu?1:C.explore?.85:0,re=C.explore&&!o?1:0;Fn.to(y,{dim:W,explore:re,duration:o?.3:1.1,ease:"power2.out",overwrite:"auto"})}function k(W,re){I=W,u.uTime.value=re,Qd(_,y.mood),b(_),x.update(W,re,y,M),d.update(t);const Ae=y.enter,ee=_.grade;m.setGrade(ee,.32+.68*Ae*Ae),P=m.setSoften(y.dim)}function Z(){f.traverse(re=>{re.layers.set(gl)});const W=t.layers.mask;t.layers.set(0),P||t.layers.enable(gl),m.composer.render(I),t.layers.mask=W}function K(W,re){w={w:W,h:re},M=W/re,t.aspect=M,t.updateProjectionMatrix(),m.composer.setSize(W,re),S()}const pe=[];if(i){const W=(re,Ae)=>{i.on(re,Ae),pe.push(()=>i.off(re,Ae))};W("step:change",re=>{re&&Number.isFinite(re.index)&&N(re.index)}),W("timeline:scrub",re=>{re&&Number.isFinite(re.t)&&R(re.t)}),W("mode:change",re=>{Fn.to(y,{timeline:re&&re.mode==="timeline"?1:0,duration:o?.4:1.6,ease:"power2.inOut",overwrite:"auto"})}),W("explore:open",()=>{C.explore=!0,T()}),W("explore:close",()=>{C.explore=!1,T()}),W("menu:open",()=>{C.menu=!0,T()}),W("menu:close",()=>{C.menu=!1,T()}),W("pointer:move",re=>{re&&x.setPointer(re.x||0,re.y||0)}),W("quality:set",re=>{re&&re.tier&&H(re.tier)}),W("intro:enter",()=>{Fn.to(y,{enter:1,duration:o?1.2:4.4,ease:"power1.inOut",overwrite:"auto"})})}function ce(){pe.forEach(W=>W()),Fn.killTweensOf(y),p(),d.dispose(),m.dispose(),c.dispose(),e.remove(h),e.remove(f)}return{update:k,resize:K,setStep:N,setTimeOfDay:R,hologramAnchor:f,composer:m.composer,render:Z,setQuality:H,dispose:ce,get quality(){return a},get state(){return y},get stats(){return{tier:a,banyanTris:v.banyan.triangles,foliage:v.foliage.count,beams:v.beams.count}}}}const Ut=new Bn,Qa=new O,h0=new we,f0=new we,d0=new we;class Ow{constructor(e){this.geometry=e.geometry,this.randomFunction=Math.random,this.indexAttribute=this.geometry.index,this.positionAttribute=this.geometry.getAttribute("position"),this.normalAttribute=this.geometry.getAttribute("normal"),this.colorAttribute=this.geometry.getAttribute("color"),this.uvAttribute=this.geometry.getAttribute("uv"),this.weightAttribute=null,this.distribution=null}setWeightAttribute(e){return this.weightAttribute=e?this.geometry.getAttribute(e):null,this}build(){const e=this.indexAttribute,t=this.positionAttribute,i=this.weightAttribute,r=e?e.count/3:t.count/3,s=new Float32Array(r);for(let l=0;l<r;l++){let c=1,u=3*l,h=3*l+1,f=3*l+2;e&&(u=e.getX(u),h=e.getX(h),f=e.getX(f)),i&&(c=i.getX(u)+i.getX(h)+i.getX(f)),Ut.a.fromBufferAttribute(t,u),Ut.b.fromBufferAttribute(t,h),Ut.c.fromBufferAttribute(t,f),c*=Ut.getArea(),s[l]=c}const o=new Float32Array(r);let a=0;for(let l=0;l<r;l++)a+=s[l],o[l]=a;return this.distribution=o,this}setRandomGenerator(e){return this.randomFunction=e,this}sample(e,t,i,r){const s=this.sampleFaceIndex();return this.sampleFace(s,e,t,i,r)}sampleFaceIndex(){const e=this.distribution[this.distribution.length-1];return this.binarySearch(this.randomFunction()*e)}binarySearch(e){const t=this.distribution;let i=0,r=t.length-1,s=-1;for(;i<=r;){const o=Math.ceil((i+r)/2);if(o===0||t[o-1]<=e&&t[o]>e){s=o;break}else e<t[o]?r=o-1:i=o+1}return s}sampleFace(e,t,i,r,s){let o=this.randomFunction(),a=this.randomFunction();o+a>1&&(o=1-o,a=1-a);const l=this.indexAttribute;let c=e*3,u=e*3+1,h=e*3+2;return l&&(c=l.getX(c),u=l.getX(u),h=l.getX(h)),Ut.a.fromBufferAttribute(this.positionAttribute,c),Ut.b.fromBufferAttribute(this.positionAttribute,u),Ut.c.fromBufferAttribute(this.positionAttribute,h),t.set(0,0,0).addScaledVector(Ut.a,o).addScaledVector(Ut.b,a).addScaledVector(Ut.c,1-(o+a)),i!==void 0&&(this.normalAttribute!==void 0?(Ut.a.fromBufferAttribute(this.normalAttribute,c),Ut.b.fromBufferAttribute(this.normalAttribute,u),Ut.c.fromBufferAttribute(this.normalAttribute,h),i.set(0,0,0).addScaledVector(Ut.a,o).addScaledVector(Ut.b,a).addScaledVector(Ut.c,1-(o+a)).normalize()):Ut.getNormal(i)),r!==void 0&&this.colorAttribute!==void 0&&(Ut.a.fromBufferAttribute(this.colorAttribute,c),Ut.b.fromBufferAttribute(this.colorAttribute,u),Ut.c.fromBufferAttribute(this.colorAttribute,h),Qa.set(0,0,0).addScaledVector(Ut.a,o).addScaledVector(Ut.b,a).addScaledVector(Ut.c,1-(o+a)),r.r=Qa.x,r.g=Qa.y,r.b=Qa.z),s!==void 0&&this.uvAttribute!==void 0&&(h0.fromBufferAttribute(this.uvAttribute,c),f0.fromBufferAttribute(this.uvAttribute,u),d0.fromBufferAttribute(this.uvAttribute,h),s.set(0,0).addScaledVector(h0,o).addScaledVector(f0,a).addScaledVector(d0,1-(o+a))),this}}const Fe={SURF:0,EDGE:1,LINE:2,SCREEN:3,TRACE:4,GLYPH:5,FLUID:6,VORTEX:8},el=.75,p0=new Mi,m0=new Hi,g0=new O,dr=new O;function Fl(n,e,t){const i=new It;return p0.set(e?e[0]:0,e?e[1]:0,e?e[2]:0,"YXZ"),m0.setFromEuler(p0),t==null?dr.set(1,1,1):Array.isArray(t)?dr.set(t[0],t[1],t[2]):dr.set(t,t,t),g0.set(n?n[0]:0,n?n[1]:0,n?n[2]:0),i.compose(g0,m0,dr)}function ou(n){let e=n>>>0;return function(){e=e+1831565813>>>0;let i=e;return i=Math.imul(i^i>>>15,i|1),i^=i+Math.imul(i^i>>>7,i|61),((i^i>>>14)>>>0)/4294967296}}class v0{constructor(e=4096){this.a=new Float32Array(e),this.n=0}push(...e){if(this.n+e.length>this.a.length){const t=new Float32Array(Math.max(this.a.length*2,this.n+e.length));t.set(this.a),this.a=t}for(let t=0;t<e.length;t++)this.a[this.n++]=e[t]}}const tl=12;class go{constructor(e){this.name=e,this.stack=[new It],this.surfs=[],this.lineProps=[],this.segs=new v0(32768),this.spinning=!1,this.spin=null}spinGroup(e,t,i,r){const s=new O(e[0],e[1],e[2]).applyMatrix4(this.top),o=new O(t[0],t[1],t[2]).transformDirection(this.top);this.spin={c:s.toArray(),d:o.toArray(),w:i},this.spinning=!0;try{r()}finally{this.spinning=!1}}get top(){return this.stack[this.stack.length-1]}push(e,t,i){return this.stack.push(this.top.clone().multiply(Fl(e,t,i))),this}pop(){return this.stack.length>1&&this.stack.pop(),this}group(e,t){this.push(e.at,e.rot,e.s);try{t()}finally{this.pop()}}surface(e,t={}){const i=this.top.clone().multiply(Fl(t.at,t.rot,t.s)),r=e.index?e.toNonIndexed():e;r.attributes.normal||r.computeVertexNormals();let s=null;const o=r.attributes.position;if(t.weightFn){s=new Float32Array(o.count);for(let c=0;c<o.count;c++)s[c]=Math.max(0,t.weightFn(o.getX(c),o.getY(c),o.getZ(c)))}const a=t.edges??"auto",l={kind:Fe.EDGE,density:t.edgeDensity??1,bright:t.edgeBright??1,isEdge:!0,param:this.spinning?el:0};if(a==="auto"){const c=new h2(e,t.edgeAngle??30),u=c.attributes.position.array,h=this._lineIndex({...l,radius:0}),f=new O,d=new O;for(let v=0;v<u.length;v+=6)f.set(u[v],u[v+1],u[v+2]).applyMatrix4(i),d.set(u[v+3],u[v+4],u[v+5]).applyMatrix4(i),this._seg(f,d,l.param,l.param,0,h);c.dispose()}else if(Array.isArray(a))for(const c of a)this._polyline(c.map(u=>au(u).applyMatrix4(i)),{...l,closed:c.closed});return r.applyMatrix4(i),this.surfs.push({pos:r.attributes.position.array,nrm:r.attributes.normal.array,count:o.count,weights:s,density:t.density??1,kind:t.kind??Fe.SURF,bright:t.bright??1,param:this.spinning?el:t.param??0}),e!==r&&e.dispose(),this}line(e,t={}){const i=this.top,r=e.map(o=>au(o).applyMatrix4(i));dr.setFromMatrixScale(i);const s=(Math.abs(dr.x)+Math.abs(dr.y)+Math.abs(dr.z))/3;return this._polyline(r,{...t,radius:(t.radius??0)*s,ribs:t.ribs?t.ribs*s:0}),this}curve(e,t={}){const i=e.map(au),r=new ip(i,!!t.closed,"centripetal",t.tension??.5);let s=0;for(let a=1;a<i.length;a++)s+=i[a].distanceTo(i[a-1]);const o=t.segments??Math.max(12,Math.min(400,Math.ceil(s/.008)));return this.line(r.getPoints(o),{...t,closed:!1})}_lineIndex(e){return this.lineProps.push({radius:e.radius??0,density:e.density??1,kind:e.kind??Fe.LINE,bright:e.bright??1,param:this.spinning?el:typeof e.param=="number"?e.param:0,ribs:e.ribs??0,ribAmp:e.ribAmp??.22,isEdge:!!e.isEdge,jitter:e.jitter??0}),this.lineProps.length-1}_seg(e,t,i,r,s,o){const a=e.distanceTo(t);return a<1e-7?0:(this.segs.push(e.x,e.y,e.z,t.x,t.y,t.z,a,i,r,s,o,0),a)}_polyline(e,t){t.closed&&e.length>2&&(e=[...e,e[0].clone()]);let i=0;for(let u=0;u<e.length-1;u++)i+=e[u].distanceTo(e[u+1]);if(i<1e-7)return;const r=this._lineIndex(t),s=t.param==="u"&&!this.spinning,o=t.u0??0,a=t.u1??1,l=this.spinning?el:typeof t.param=="number"?t.param:0;let c=0;for(let u=0;u<e.length-1;u++){const h=e[u].distanceTo(e[u+1]),f=s?o+(a-o)*(c/i):l,d=s?o+(a-o)*((c+h)/i):l;this._seg(e[u],e[u+1],f,d,c,r),c+=h}}sample(e,t,i={}){const r=i.lineK??.03,s=i.edgeK??r,o=new Float32Array(e*4),a=new Float32Array(e*4);let l=0;for(const b of this.surfs)l+=b.count;const c=new Float32Array(l*3),u=new Float32Array(l*3),h=new Float32Array(l),f=new Float32Array(l/3*3);let d=0;for(const b of this.surfs){c.set(b.pos,d*3),u.set(b.nrm,d*3);for(let N=0;N<b.count;N++)h[d+N]=b.density*(b.weights?b.weights[N]:1);for(let N=d/3;N<(d+b.count)/3;N++)f[N*3]=b.kind,f[N*3+1]=b.bright,f[N*3+2]=b.param;d+=b.count}let v=0,g=null;if(l){const b=new Et;b.setAttribute("position",new kt(c,3)),b.setAttribute("normal",new kt(u,3)),b.setAttribute("weight",new kt(h,1)),g=new Ow(new Gt(b)).setWeightAttribute("weight").build().distribution,v=g[g.length-1]/3,b.dispose()}const p=this.segs.a,m=this.segs.n/tl,x=new Float64Array(m);let _=0;for(let b=0;b<m;b++){const N=this.lineProps[p[b*tl+10]];_+=p[b*tl+6]*(N.isEdge?s:r)*N.density,x[b]=_}const y=v+_,C=y>0?Math.round(e*v/y):0,M=(b,N)=>{let R=0,H=b.length-1;for(;R<H;){const T=R+H>>1;b[T]<=N?R=T+1:H=T}return R};let w=0;if(g){const b=g[g.length-1];for(;w<C;w++){const N=M(g,t()*b);let R=t(),H=t();R+H>1&&(R=1-R,H=1-H);const T=1-R-H,k=N*9,Z=c[k]*R+c[k+3]*H+c[k+6]*T,K=c[k+1]*R+c[k+4]*H+c[k+7]*T,pe=c[k+2]*R+c[k+5]*H+c[k+8]*T;let ce=u[k]*R+u[k+3]*H+u[k+6]*T,W=u[k+1]*R+u[k+4]*H+u[k+7]*T,re=u[k+2]*R+u[k+5]*H+u[k+8]*T;const Ae=Math.hypot(ce,W,re)||1;ce/=Ae,W/=Ae,re/=Ae,o[w*4]=Z,o[w*4+1]=K,o[w*4+2]=pe,o[w*4+3]=f[N*3]+Math.min(.999,Math.max(0,f[N*3+2])),a[w*4]=ce,a[w*4+1]=W,a[w*4+2]=re,a[w*4+3]=f[N*3+1]}}const P=new Float32Array(m*6),I=new Uint8Array(m);let S=0;for(;w<e&&m&&S<e*20;){S++;const b=M(x,t()*_),N=b*tl,R=this.lineProps[p[N+10]],H=t(),T=p[N+6];let k=R.radius;if(R.ribs>0){const G=Math.cos((p[N+9]+H*T)/R.ribs*Math.PI*2),he=.5+.5*G;if(t()>.08+.92*he*he*he)continue;k*=1+R.ribAmp*G}const Z=(p[N+3]-p[N])/T,K=(p[N+4]-p[N+1])/T,pe=(p[N+5]-p[N+2])/T;let ce=p[N]+Z*T*H,W=p[N+1]+K*T*H,re=p[N+2]+pe*T*H,Ae=0,ee=0,F=0;if(k>0){if(!I[b]){let De=0,se=1,U=0;Math.abs(K)>.9&&(De=1,se=0);let Se=K*U-pe*se,ye=pe*De-Z*U,ge=Z*se-K*De;const B=Math.hypot(Se,ye,ge)||1;Se/=B,ye/=B,ge/=B;const q=K*ge-pe*ye,V=pe*Se-Z*ge,A=Z*ye-K*Se;P.set([Se,ye,ge,q,V,A],b*6),I[b]=1}const G=t()*Math.PI*2,he=Math.cos(G),me=Math.sin(G),fe=b*6;Ae=P[fe]*he+P[fe+3]*me,ee=P[fe+1]*he+P[fe+4]*me,F=P[fe+2]*he+P[fe+5]*me,ce+=Ae*k,W+=ee*k,re+=F*k}else R.jitter&&(ce+=(t()-.5)*R.jitter,W+=(t()-.5)*R.jitter,re+=(t()-.5)*R.jitter);const xe=p[N+7]+(p[N+8]-p[N+7])*H;o[w*4]=ce,o[w*4+1]=W,o[w*4+2]=re,o[w*4+3]=R.kind+Math.min(.999,Math.max(0,xe)),a[w*4]=Ae,a[w*4+1]=ee,a[w*4+2]=F,a[w*4+3]=R.bright,w++}for(;w<e;w++)o[w*4+3]=Fe.EDGE,a[w*4+3]=0;return{pos:o,nrm:a,nSurf:C,nLine:e-C}}dispose(){this.surfs.length=0,this.lineProps.length=0,this.segs=new v0(16)}}function au(n){return n.isVector3?n.clone():new O(n[0],n[1],n[2])}function kw(n,e,t,{height:i=2.5,maxSpan:r=3.3,yaw:s=0,pivot:o=null}={}){const a=Math.cos(s),l=Math.sin(s);let c=1/0,u=-1/0,h=1/0,f=-1/0,d=1/0,v=-1/0;for(let M=0;M<t*4;M+=4){const w=n[M],P=n[M+2],I=w*a+P*l,S=-w*l+P*a;n[M]=I,n[M+2]=S;const b=e[M],N=e[M+2];e[M]=b*a+N*l,e[M+2]=-b*l+N*a;const R=n[M+1];I<c&&(c=I),I>u&&(u=I),R<h&&(h=R),R>f&&(f=R),S<d&&(d=S),S>v&&(v=S)}const g=f-h,p=Math.max(u-c,v-d),m=Math.min(i/g,r/p);let x=(c+u)/2,_=(d+v)/2;o&&(x=o[0]*a+o[1]*l,_=-o[0]*l+o[1]*a);for(let M=0;M<t*4;M+=4)n[M]=(n[M]-x)*m,n[M+1]=(n[M+1]-h)*m,n[M+2]=(n[M+2]-_)*m;const y=M=>[(M[0]*a+M[2]*l-x)*m,(M[1]-h)*m,(-M[0]*l+M[2]*a-_)*m],C=M=>[M[0]*a+M[2]*l,M[1],-M[0]*l+M[2]*a];return{scale:m,size:[(u-c)*m,g*m,(v-d)*m],point:y,dir:C}}function Bw(n,e,{cell:t=.045,ref:i=88,power:r=.5,min:s=.6,max:o=1.35}={}){const a=new Map;for(let c=0;c<e*4;c+=4){const u=Math.floor(n[c]/t)*4096+Math.floor(n[c+1]/t);a.set(u,(a.get(u)||0)+1)}const l=e/Math.max(1,a.size);return Math.min(o,Math.max(s,Math.pow(i/l,r)))}const zw=[1,2.4,1.8,.9,3.2,3.2,1.4,3,1];function Hw(n,e,t,i){const s=new Uint16Array(t),o=new Uint32Array(8193);for(let u=0;u<t;u++){const h=zw[Math.floor(n[u*4+3])]||1,f=Math.pow(i(),1/h),d=8191-Math.min(8191,Math.floor(f*8192));s[u]=d,o[d+1]++}for(let u=0;u<8192;u++)o[u+1]+=o[u];const a=new Uint32Array(t);for(let u=0;u<t;u++)a[o[s[u]]++]=u;const l=new Float32Array(t*4),c=new Float32Array(t*4);for(let u=0;u<t;u++){const h=a[u]*4,f=u*4;l[f]=n[h],l[f+1]=n[h+1],l[f+2]=n[h+2],l[f+3]=n[h+3],c[f]=e[h],c[f+1]=e[h+1],c[f+2]=e[h+2],c[f+3]=e[h+3]}n.set(l),e.set(c)}const vo=Math.PI*2;let Ls=null;function Gw(n,e,t,i){if(!Ls){const f=new fo(1,1,1,5,5,5);Ls=f.toNonIndexed().attributes.position.array,f.dispose()}const r=Ls.length,s=new Float32Array(r),o=new Float32Array(r),a=n/2-i,l=e/2-i,c=t/2-i,u=.5/5;for(let f=0;f<r;f+=3){const d=Ls[f],v=Ls[f+1],g=Ls[f+2],p=Math.sign(d),m=Math.sign(v),x=Math.sign(g);let _=d-p*u,y=v-m*u,C=g-x*u;const M=Math.hypot(_,y,C)||1;_/=M,y/=M,C/=M,s[f]=a*p+_*i,s[f+1]=l*m+y*i,s[f+2]=c*x+C*i,o[f]=_,o[f+1]=y,o[f+2]=C}const h=new Et;return h.setAttribute("position",new kt(s,3)),h.setAttribute("normal",new kt(o,3)),h}function ze(n,e,t,i,r,s={}){r=Math.max(.0015,Math.min(r,e/2-1e-4,t/2-1e-4,i/2-1e-4));const o=Gw(e,t,i,r),a=s.edges===!1?!1:Vw(e,t,i,r);n.surface(o,{...s,edges:a})}function Vw(n,e,t,i){const r=i*.293,s=n/2-r,o=e/2-r,a=t/2-r,l=[];for(const c of[-1,1])for(const u of[-1,1])l.push([[-s,c*o,u*a],[s,c*o,u*a]]),l.push([[c*s,-o,u*a],[c*s,o,u*a]]),l.push([[c*s,u*o,-a],[c*s,u*o,a]]);return l}function Ke(n,e,t,i,r={}){const s=r.seg??Math.max(14,Math.min(64,Math.round(Math.max(e,t)*260))),o=new Hh(e,t,i,s,1,!!r.open),a=Math.max(16,s),l=r.edges??[br(0,i/2,0,e,"y",a),br(0,-i/2,0,t,"y",a)];n.surface(o,{...r,edges:l})}function _r(n,e,t={}){const i=new jl(e,t.wSeg??24,t.hSeg??16,t.phiStart??0,t.phiLength??vo,t.thetaStart??0,t.thetaLength??Math.PI);n.surface(i,{edges:!1,...t})}function Ww(n,e,t={}){const i=new da(e,t.seg??32);i.rotateX(-Math.PI/2),n.surface(i,{edges:!1,...t})}function is(n,e,t={}){const i=new zh(e.map(([r,s])=>new we(r,s)),t.seg??40,t.phiStart??0,t.phiLength??vo);n.surface(i,{edgeAngle:35,...t})}function co(n,e,t,i={}){const r=new Gh(e,{depth:t,bevelEnabled:(i.bevel??0)>0,bevelThickness:i.bevel??0,bevelSize:i.bevel??0,bevelSegments:i.bevelSeg??2,curveSegments:i.curveSeg??48});r.translate(0,0,-t/2),n.surface(r,{edgeAngle:32,...i})}function Am(n,e){const t=e[0]-n[0],i=e[1]-n[1],r=e[2]-n[2],s=Math.hypot(t,i,r)||1e-6;return{len:s,rot:[Math.acos(Math.max(-1,Math.min(1,i/s))),Math.atan2(t,r),0],mid:[(n[0]+e[0])/2,(n[1]+e[1])/2,(n[2]+e[2])/2]}}function _t(n,e,t,i,r=i,s={}){const{len:o,rot:a,mid:l}=Am(e,t);Ke(n,r,i,o,{...s,at:l,rot:a})}function si(n,e,t,i,r,s,o={}){const{len:a,rot:l,mid:c}=Am(e,t);ze(n,i,a,r,s,{...o,at:c,rot:l})}function pt(n,e,t,i,r,s="y",o={}){n.line(br(e,t,i,r,s,o.n??Math.max(20,Math.min(96,Math.round(r*600)))),{kind:o.kind??Fe.EDGE,density:o.density??1.4,bright:o.bright??1})}function _0(n,e,t,i,r={}){const s=new O(t[0],t[1],t[2]).normalize(),o=(Math.abs(s.y)>.9?new O(1,0,0):new O(0,1,0)).cross(s).normalize(),a=s.clone().cross(o),l=r.n??Math.max(20,Math.min(96,Math.round(i*600))),c=[];for(let u=0;u<=l;u++){const h=u/l*vo,f=Math.cos(h)*i,d=Math.sin(h)*i;c.push([e[0]+f*o.x+d*a.x,e[1]+f*o.y+d*a.y,e[2]+f*o.z+d*a.z])}n.line(c,{kind:r.kind??Fe.EDGE,density:r.density??1.4,bright:r.bright??1})}function un(n,e,t,i,r={}){n.line([e,t],{radius:i,kind:Fe.LINE,...r})}function mt(n,e,t,i={}){n.curve(e,{radius:t,kind:Fe.LINE,...i})}function br(n,e,t,i,r="y",s=48,o=0,a=vo){const l=[];for(let c=0;c<=s;c++){const u=o+(a-o)*c/s,h=Math.cos(u)*i,f=Math.sin(u)*i;r==="y"?l.push([n+h,e,t+f]):r==="z"?l.push([n+h,e+f,t]):l.push([n,e+h,t+f])}return l}function ec(n,e,t,i={}){const r=i.r??.05,s=i.w??.032,o=i.stem??.03,a=r*.35;return n.group({at:[e,0,t],rot:[0,i.yaw??0,0]},()=>{Ke(n,r,r,s,{at:[0,r,-a],rot:[0,0,Math.PI/2],density:1.1,edgeDensity:1.4}),Ke(n,r*.42,r*.42,s+.006,{at:[0,r,-a],rot:[0,0,Math.PI/2],density:.4,edgeDensity:.8});for(const l of[-1,1])ze(n,.006,r*1.3,r*1.1,.002,{at:[l*(s/2+.006),r*1.35,-a*.6],density:.8,edgeDensity:.7});ze(n,s+.026,.008,r*1.1,.002,{at:[0,2*r+.006,-a*.6],density:.8,edgeDensity:.7}),Ke(n,.009,.009,o,{at:[0,2*r+.01+o/2,0],density:.7})}),2*r+.01+o}function Xw(n,e={}){const t=e.legs??5,i=e.R??.3,r=e.casterR??.038,s=e.legH??.03,o=e.legW??.04,a=e.hubR??.05,c=2*r+.01+.025+s/2;Ke(n,a*.9,a,s*2.2,{at:[0,c+s*.3,0],density:1.2});for(let u=0;u<t;u++){const h=(e.phase??Math.PI/2)+vo*u/t;n.group({rot:[0,-h,0]},()=>{const f=i-a*.6;ze(n,f,s,o,s*.45,{at:[a*.6+f/2,c+.006,0],rot:[0,0,-.035],density:1.1,edgeDensity:1.2}),ec(n,i-.012,0,{r,w:.026,stem:.022,yaw:h*.7+u})})}return c+s*1.4}const qw={a:[[0,1],[.56,1]],b:[[.56,1],[.56,.5]],c:[[.56,.5],[.56,0]],d:[[0,0],[.56,0]],e:[[0,0],[0,.5]],f:[[0,.5],[0,1]],g:[[0,.5],[.56,.5]]},$w={0:"abcdef",1:"bc",2:"abged",3:"abgcd",4:"fgbc",5:"afgcd",6:"afgedc",7:"abc",8:"abcdefg",9:"abcdfg","-":"g"};function pr(n,e,t,i,r,s,o={}){let a=t;const l=.12;for(const c of String(e)){if(c===" "){a+=s*.5;continue}if(c==="."){n.line([[a+s*.04,i,r],[a+s*.1,i,r]],{kind:Fe.GLYPH,density:o.density??5,bright:o.bright??1.4}),a+=s*.22;continue}if(c==="/"){n.line([[a,i,r],[a+s*.4,i+s,r]],{kind:Fe.GLYPH,density:o.density??5,bright:o.bright??1.4}),a+=s*.5;continue}const u=$w[c];if(!u){a+=s*.6;continue}for(const h of u){const[[f,d],[v,g]]=qw[h],p=[a+(f+d*l)*s,i+d*s,r],m=[a+(v+g*l)*s,i+g*s,r],x=.07,_=[p[0]+(m[0]-p[0])*x,p[1]+(m[1]-p[1])*x,r],y=[m[0]+(p[0]-m[0])*x,m[1]+(p[1]-m[1])*x,r];n.line([_,y],{kind:Fe.GLYPH,density:o.density??5,bright:o.bright??1.4})}a+=s*.84}return a}const Gr=(n,e,t)=>Math.exp(-((n-e)*(n-e))/(2*t*t)),x0=n=>.12*Gr(n,.17,.028)-.12*Gr(n,.355,.009)+1*Gr(n,.385,.011)-.26*Gr(n,.415,.011)+.3*Gr(n,.64,.05),Yw=n=>{const e=(n+.75)%1;return .95*Gr(e,.22,.075)+.42*Gr(e,.47,.1)+.05},Kw=n=>.5+.5*Math.sin(n*vo-1.2);function nl(n,e,t,i,r,s,o,a={}){const l=a.beats??4,c=a.n??260,u=[];for(let h=0;h<=c;h++){const f=h/c,d=(f*l+(a.phase??0))%1;u.push([t+(i-t)*f,r+e(d)*s,o])}n.line(u,{kind:a.swept===!1?Fe.GLYPH:Fe.TRACE,param:a.swept===!1?a.param??0:"u",u0:a.u0??0,u1:a.u1??1,density:a.density??4,bright:a.bright??1.3})}function Ol(n,e,t,i,r={}){const s=new as(e,t,1,1);n.surface(s,{at:[r.cx??0,r.cy??0,i],kind:Fe.SCREEN,density:r.density??.4,bright:r.bright??1,edges:[[[-e/2,-t/2,0],[e/2,-t/2,0],[e/2,t/2,0],[-e/2,t/2,0],[-e/2,-t/2,0]]],edgeDensity:r.edgeDensity??1.6,edgeBright:r.edgeBright??1.1})}function uo(n,e,t,i,r,s,o={}){n.line([[e-i/2,t-r/2,s],[e+i/2,t-r/2,s],[e+i/2,t+r/2,s],[e-i/2,t+r/2,s],[e-i/2,t-r/2,s]],{kind:o.kind??Fe.GLYPH,density:o.density??2.5,bright:o.bright??.9})}function Vs(n,e,t,i,r,s,o={}){let a=e;for(const l of r)n.line([[a,t,i],[a+l,t,i]],{kind:Fe.GLYPH,density:o.density??3,bright:o.bright??.7}),a+=l+s*.6}function jw(){const n=new go("monitor"),e=Xw(n,{R:.31,casterR:.04,legH:.032,legW:.044,hubR:.058}),t=e+.62,i=1.07;Ke(n,.02,.022,t-e,{at:[0,(e+t)/2,0],density:1.2}),Ke(n,.016,.016,i-t+.05,{at:[0,(t+i)/2-.025,0],density:1.2}),Ke(n,.028,.028,.05,{at:[0,t,0]}),Ke(n,.008,.008,.045,{at:[.045,t,0],rot:[0,0,Math.PI/2]}),Ke(n,.017,.017,.014,{at:[.072,t,0],rot:[0,0,Math.PI/2]}),Zw(n,0,.83,.1,.27,.11,.15),ze(n,.05,.04,.03,.01,{at:[0,.86,.02]}),ze(n,.15,.035,.08,.016,{at:[-.03,.81,.1],rot:[0,.15,.08],density:.8}),Ke(n,.03,.03,.06,{at:[0,i+.01,0]}),ze(n,.24,.016,.17,.006,{at:[0,i+.048,-.01]});const r=1.36,s=i+.056+.17*r;n.group({at:[0,s,0],rot:[-.05,0,0],s:r},()=>{ze(n,.41,.34,.05,.022,{at:[0,0,.035],density:.8}),ze(n,.35,.28,.11,.035,{at:[0,-.005,-.045],density:.7});for(let h=0;h<8;h++)n.line([[-.1,-.07+h*.018,-.101],[.1,-.07+h*.018,-.101]],{kind:Fe.EDGE,density:.8,bright:.55});mt(n,[[-.14,.15,-.035],[-.135,.205,-.04],[0,.218,-.04],[.135,.205,-.04],[.14,.15,-.035]],.012),ze(n,.11,.016,.03,.007,{at:[.115,.178,.035],kind:Fe.EDGE,bright:1.6,density:1.6}),ze(n,.012,.15,.08,.004,{at:[-.177,-.02,-.04],density:.6});for(let h=0;h<4;h++)n.line(br(-.184,.035-h*.035,-.04,.011,"x",18),{kind:Fe.EDGE,density:1.6});const a=.035+.025+.002;Ol(n,.345,.255,a,{cx:-.01,cy:.022});const l=a+.002,c=-.175,u=.05;nl(n,x0,c,u,.098,.042,l,{beats:3.2,phase:.2,density:5}),nl(n,h=>.7*x0(h)-.15*Math.exp(-((h-.4)**2)/4e-4),c,u,.044,.03,l,{beats:3.2,phase:.2,density:4}),nl(n,Yw,c,u,-.03,.04,l,{beats:3.2,phase:.33,density:4}),nl(n,Kw,c,u,-.088,.026,l,{beats:1.1,phase:.1,density:3.5}),n.line([[.058,-.1,l],[.058,.145,l]],{kind:Fe.GLYPH,density:1.2,bright:.4}),Vs(n,.066,.138,l,[.016,.01],.008,{bright:.6}),pr(n,"72",.068,.078,l,.05,{bright:1.5}),n.line([[.062,.066,l],[.155,.066,l]],{kind:Fe.GLYPH,density:1,bright:.35}),Vs(n,.066,.056,l,[.02,.008],.008,{bright:.6}),pr(n,"98",.068,.006,l,.042,{bright:1.4}),n.line([[.062,-.006,l],[.155,-.006,l]],{kind:Fe.GLYPH,density:1,bright:.35}),pr(n,"118/76",.064,-.045,l,.022,{bright:1.2}),n.line([[.062,-.058,l],[.155,-.058,l]],{kind:Fe.GLYPH,density:1,bright:.35}),pr(n,"16",.068,-.098,l,.03,{bright:1.2}),Vs(n,.118,-.08,l,[.022],.008,{bright:.5}),Vs(n,-.17,.138,l,[.04,.025,.03],.01,{bright:.5});for(let h=0;h<5;h++)uo(n,-.165+h*.056,-.135,.042,.016,a,{kind:Fe.EDGE,bright:.8});Ke(n,.022,.022,.018,{at:[.155,-.133,a+.006],rot:[Math.PI/2,0,0],edgeDensity:1.6}),_r(n,.005,{at:[-.185,-.135,a],kind:Fe.GLYPH,bright:1.6,density:4})});const o=-.19*r;mt(n,[[o,s+.03,-.04],[-.25,s-.03,-.02],[-.29,s-.2,.02],[-.25,.92,.07],[-.12,.86,.1],[-.05,.84,.1]],.0045,{density:1.3}),mt(n,[[o,s-.005,-.04],[-.24,s-.08,-.04],[-.26,1,0],[-.2,.9,.06],[-.08,.86,.12]],.0035,{density:1.2}),mt(n,[[o,s-.04,-.04],[-.26,s-.12,-.06],[-.3,.98,-.04],[-.27,.78,.04],[-.12,.72,.13],[.04,.76,.14],[.08,.81,.12]],.0055,{density:1.3});for(let a=0;a<5;a++){const l=-.5+a*.25;mt(n,[[-.05,.84,.1],[-.02+a*.02,.8,.13],[.03+Math.sin(l)*.08,.74-a*.012,.17+Math.cos(l)*.02],[.06+Math.sin(l)*.1,.66-a*.02,.16]],.002,{density:.8})}return mt(n,[[.06,s-.12,-.1],[.04,i-.05,-.05],[.025,.7,-.03],[.03,.3,-.04],[.08,.12,-.12],[.2,.01,-.2]],.004,{density:.8}),n}function Zw(n,e,t,i,r,s,o){const a=e-r/2,l=e+r/2,c=i-o/2,u=i+o/2,h=t-s/2,f=t+s/2,d={radius:.0025,density:1,kind:Fe.LINE};n.line([[a,f,c],[l,f,c],[l,f,u],[a,f,u],[a,f,c]],{...d,radius:.004,density:1.5}),n.line([[a,h,c],[l,h,c],[l,h,u],[a,h,u],[a,h,c]],d);for(let v=0;v<=8;v++){const g=a+r*v/8;n.line([[g,h,u],[g,f,u]],d),n.line([[g,h,c],[g,h,u]],d)}for(let v=0;v<=4;v++){const g=c+o*v/4;n.line([[a,h,g],[a,f,g]],d),n.line([[l,h,g],[l,f,g]],d)}un(n,[e,f,c],[e,f,c-.06],.004)}const Nn=(n,e)=>new we(n,e),Jw=new O,Qw=(n,e)=>Jw.set(e[0],e[1],e[2]).applyMatrix4(n).toArray();function eE(){const n=new go("dental");ze(n,1.16,.045,.6,.022,{at:[-.02,.0225,0],density:.35}),ze(n,.42,.2,.46,.07,{at:[-.44,.145,0],density:.6}),si(n,[-.32,.17,0],[.2,.45,0],.3,.15,.05,{density:.65}),ze(n,.5,.07,.46,.03,{at:[.25,.49,0],rot:[0,0,.03],density:.5});const e=new no;e.moveTo(0,.62),e.splineThru([Nn(.18,.632),Nn(.38,.652),Nn(.52,.646),Nn(.7,.59),Nn(.9,.525),Nn(1.04,.48)]),e.quadraticCurveTo(1.1,.455,1.05,.41),e.splineThru([Nn(.88,.455),Nn(.68,.52),Nn(.5,.566),Nn(.36,.572),Nn(.18,.55),Nn(0,.535)]),e.lineTo(0,.62),co(n,e,.5,{density:.75,curveSeg:10});const t=[-Math.cos(.873),Math.sin(.873)],i=[t[1],-t[0]],r=.68,s=(I,S)=>[0+t[0]*r*I+i[0]*S,.625+t[1]*r*I+i[1]*S],o=[0,.026,.03,.02,.008,0],a=new no,l=s(0,0);a.moveTo(l[0],l[1]),a.splineThru(o.slice(1).map((I,S)=>Nn(...s((S+1)/5,I))));const c=s(1,0),u=[c[0]-i[0]*.1,c[1]-i[1]*.1];a.quadraticCurveTo(c[0]+t[0]*.06-i[0]*.05,c[1]+t[1]*.06-i[1]*.05,u[0],u[1]),a.lineTo(l[0]-i[0]*.1,l[1]-i[1]*.1),a.lineTo(l[0],l[1]),co(n,a,.54,{density:.75,curveSeg:10});const h=Math.atan2(t[1],t[0]),f=[c[0]+t[0]*.19-i[0]*.03,c[1]+t[1]*.19-i[1]*.03];ze(n,.25,.075,.28,.034,{at:[f[0],f[1],0],rot:[0,0,h+.14],density:.9});for(const I of[-.07,.07])un(n,[c[0]-i[0]*.055-t[0]*.05,c[1]-i[1]*.055-t[1]*.05,I],[f[0]-t[0]*.08,f[1]-t[1]*.08,I],.009);ze(n,.34,.045,.085,.02,{at:[.27,.775,-.31],rot:[0,0,-.04],density:.8}),mt(n,[[.06,.53,-.27],[.08,.66,-.31],[.13,.74,-.31],[.19,.755,-.31]],.016);const d=-.6,v=-.2;_t(n,[d,.245,v],[d,1.78,v],.034,.034,{density:1.1}),Ke(n,.046,.046,.08,{at:[d,1.8,v],density:1.1});const g=[-.33,2.05,-.1];si(n,[d,1.83,v],g,.066,.056,.024,{density:1}),_r(n,.04,{at:g,density:1.1});const p=[-.13,1.88,.07],m=[-.47,-Math.PI/2,0],x=Fl(p,m),_=Qw(x,[0,.2,0]);si(n,g,[_[0],_[1]+.07,_[2]],.056,.046,.02,{density:1}),_t(n,[_[0],_[1]+.08,_[2]],_,.02,.02),n.group({at:p,rot:m},()=>{mt(n,[[-.235,0,0],[-.25,.09,0],[-.2,.18,0],[0,.2,0],[.2,.18,0],[.25,.09,0],[.235,0,0]],.016,{density:1.3});for(const S of[-1,1])Ke(n,.026,.026,.03,{at:[S*.225,0,0],rot:[0,0,Math.PI/2],density:1.2});ze(n,.42,.11,.17,.05,{density:1.2,bright:1.15}),n.group({at:[0,-.057,0],rot:[Math.PI/2,0,0]},()=>{n.line(br(0,0,0,1,"z",72).map(([S,b])=>[S*.17,b*.062,0]),{kind:Fe.GLYPH,density:3,bright:1.1});for(const S of[-.105,0,.105])pt(n,S,0,0,.036,"z",{kind:Fe.GLYPH,bright:1.5,density:3}),pt(n,S,0,0,.016,"z",{kind:Fe.GLYPH,bright:1.7,density:4})});for(const S of[-1,1])mt(n,[[S*.21,-.02,.07],[S*.27,-.03,.06],[S*.3,-.03,0],[S*.27,-.03,-.06],[S*.21,-.02,-.07]],.011)}),ze(n,.08,.06,.12,.015,{at:[.02,.45,.25],density:.9}),_t(n,[.02,.42,.29],[.02,.8,.29],.032,.032,{density:1.1}),si(n,[.02,.8,.29],[.16,.8,.55],.06,.05,.02,{density:1}),Ke(n,.04,.04,.065,{at:[.16,.8,.55],density:1.1}),si(n,[.16,.81,.55],[.36,.9,.66],.05,.04,.016,{density:1});const y=.56,C=.93,M=.7;ze(n,.44,.075,.26,.03,{at:[y,C,M],density:.95}),ze(n,.36,.014,.22,.006,{at:[y+.02,C+.052,M-.01],density:.6});for(let I=0;I<4;I++)un(n,[y-.08+I*.05,C+.064,M-.08],[y-.1+I*.05,C+.064,M+.07],.0035);n.group({at:[y-.222,C,M],rot:[0,-Math.PI/2,0]},()=>{uo(n,0,.005,.15,.045,0,{kind:Fe.GLYPH,bright:.9}),Vs(n,-.06,.012,.001,[.025,.018,.03],.01,{bright:.8});for(let I=0;I<4;I++)pt(n,-.05+I*.033,-.006,.001,.006,"z",{kind:Fe.GLYPH,bright:1.2,density:3})}),[{r:.0075,len:.16,head:"rotor"},{r:.0105,len:.18,head:"contra"},{r:.008,len:.15,head:"syringe"},{r:.009,len:.15,head:"scaler"},{r:.0075,len:.16,head:"rotor"}].forEach((I,S)=>{const b=y-.17+S*.085,N=M+.145;ze(n,.034,.03,.03,.008,{at:[b,C-.022,N],density:.9});const R=[b,C-.04,N+.012],H=[b-.02,C-.04+I.len*.94,N+.012+I.len*.3];_t(n,R,H,I.r*.9,I.r,{density:1.6,edgeDensity:1.6});const T=[(H[0]-R[0])/I.len,(H[1]-R[1])/I.len,(H[2]-R[2])/I.len];if(I.head==="rotor"||I.head==="contra"){const Z=[H[0]+T[0]*.02,H[1]+T[1]*.02,H[2]+T[2]*.02];un(n,H,Z,I.r*.8,{density:1.4}),_t(n,Z,[Z[0],Z[1]-.004,Z[2]+.024],.011,.011,{density:1.6})}else I.head==="syringe"?(mt(n,[H,[H[0]+T[0]*.03,H[1]+T[1]*.03,H[2]+T[2]*.03],[H[0]-.005,H[1]+.035,H[2]+.04]],.003,{density:1.6}),ze(n,.012,.03,.012,.004,{at:[R[0],R[1]+.05,R[2]-.012],density:1.2})):mt(n,[H,[H[0]+T[0]*.02,H[1]+T[1]*.02,H[2]+T[2]*.02],[H[0],H[1]+.03,H[2]+.035]],.0022,{density:1.6});const k=.56-S%2*.035;mt(n,[[R[0],R[1],R[2]],[b,C-.17,N+.05],[b+.005,k+.02,N+.03],[b,k,N-.03],[b,k+.1,N-.1],[b,C-.12,N-.15],[b,C-.038,N-.17]],.006,{density:1.1})}),ze(n,.26,.7,.22,.05,{at:[-.3,.4,-.47],density:.6}),ze(n,.2,.08,.2,.02,{at:[-.32,.08,-.33],density:.6}),uo(n,-.3,.42,.16,.34,-.358,{kind:Fe.EDGE,bright:.6,density:1.1}),Ke(n,.035,.045,.07,{at:[-.23,.785,-.52]}),n.group({at:[-.22,.818,-.53]},()=>{is(n,[[.016,0],[.05,.004],[.095,.022],[.122,.05],[.132,.08],[.128,.09]],{density:1.1,seg:40,edges:!1}),pt(n,0,.088,0,.13,"y",{density:2.4,bright:1.25}),pt(n,0,.004,0,.022,"y",{density:2,bright:1.2})}),mt(n,[[-.36,.75,-.48],[-.37,.93,-.48],[-.33,.975,-.5],[-.27,.955,-.52]],.009),ze(n,.1,.012,.1,.004,{at:[-.37,.76,-.3],density:.9}),Ke(n,.032,.026,.085,{at:[-.37,.81,-.3],open:!0,density:1.1}),mt(n,[[-.42,.75,-.4],[-.43,.96,-.4],[-.41,1,-.36],[-.375,.985,-.31]],.008),si(n,[-.24,.74,-.42],[-.13,.87,-.38],.045,.04,.015,{density:1}),ze(n,.17,.05,.07,.015,{at:[-.08,.89,-.37],density:1});const P=[[-.13,.012,.15],[-.08,.007,.14],[-.03,.008,.13]];for(const[I,S,b]of P){const N=[I,.89,-.34],R=[I+.01,.89+b,-.3];_t(n,N,R,S,S,{density:1.5}),mt(n,[R,[R[0]+.005,R[1]+.03,R[2]+.01],[R[0]+.02,R[1]+.05,R[2]+.04]],S*.55,{density:1.4}),mt(n,[[I,.865,-.35],[I,.7,-.33],[I-.03,.6,-.33],[-.2,.6,-.35],[-.26,.66,-.36]],S>.01?.01:.007,{density:1.1})}return Ke(n,.12,.13,.04,{at:[-.12,.02,.66],density:1.1}),Ke(n,.04,.04,.012,{at:[-.12,.046,.66],density:1.2}),mt(n,br(-.12,.062,.66,.1,"y",24,-1,Math.PI+1),.008,{density:1.2}),mt(n,[[-.06,.015,.55],[0,.01,.46],[.05,.012,.36],[.08,.03,.3]],.006),n}function tE(){const n=new go("slitlamp");for(const[e,t]of[[-.15,-.25],[.27,-.25],[-.15,.25],[.27,.25]])ec(n,e,t,{r:.03,w:.024,stem:.02,yaw:e*3+t});ze(n,.5,.05,.58,.02,{at:[.06,.115,0],density:.5}),ze(n,.2,.34,.3,.03,{at:[.08,.31,0],density:.45});for(let e=0;e<4;e++)n.line([[-.021,.19+e*.07,-.11],[-.021,.19+e*.07,.11]],{kind:Fe.EDGE,density:.8,bright:.5});return ze(n,.16,.17,.26,.02,{at:[.08,.545,0],density:.5}),ze(n,.46,.05,.5,.012,{at:[.06,.645,0],density:.25}),ze(n,.6,.032,.62,.012,{at:[.06,.684,0],density:.26}),ze(n,.2,.07,.14,.015,{at:[.15,.585,-.2],density:.5}),n.group({at:[.292,.645,.16],rot:[0,Math.PI/2,0]},()=>{uo(n,0,0,.08,.03,0,{kind:Fe.EDGE,bright:.8});for(const e of[-.02,.02])pt(n,e,0,.002,.008,"z",{kind:Fe.GLYPH,bright:1.2,density:3})}),mt(n,[[0,.58,-.12],[-.05,.4,-.18],[-.1,.15,-.26],[-.2,.01,-.36]],.005,{density:.8}),n.group({at:[0,.7,0],s:1.72},()=>{ze(n,.36,.012,.36,.004,{at:[-.02,.006,0],density:.6});for(const h of[-.165,.165])un(n,[-.19,.016,h],[.15,.016,h],.006,{density:1.4});ze(n,.3,.07,.25,.022,{at:[-.02,.048,0],density:.85}),Ke(n,.019,.028,.03,{at:[.09,.098,-.05],density:1.1}),_t(n,[.09,.11,-.05],[.096,.2,-.05],.0065,.0065,{density:1.4}),Ke(n,.013,.013,.022,{at:[.095,.17,-.05],density:1.4}),_r(n,.017,{at:[.097,.215,-.05],density:1.5}),Ke(n,.024,.028,.08,{at:[-.13,.12,0],density:1.1});const i=-.13-.02;for(const h of[-.135,.135])ze(n,.045,.05,.032,.008,{at:[i,.025,h],density:1}),_t(n,[i,.03,h],[i,.56,h],.013,.013,{density:1.6,edgeDensity:1.4}),pt(n,i,.34,h,.016,"y",{density:2.5,bright:1.3});un(n,[i,.56,-.135],[i,.56,.135],.012,{density:1.6}),un(n,[i,.19,-.135],[i,.19,.135],.008,{density:1.2}),Ke(n,.02,.02,.018,{at:[i,.19,.153],rot:[Math.PI/2,0,0],density:1.2}),n.group({at:[i-.01,.198,0]},()=>{is(n,[[0,0],[.03,.004],[.045,.016],[.05,.026]],{density:1.2,seg:28,edges:!1}),pt(n,0,.026,0,.05,"y",{density:2,bright:1.1}),ze(n,.06,.008,.08,.003,{at:[0,.03,0],density:1});for(const h of[-.03,.03])un(n,[0,.02,h],[0,.07,h],.003,{density:1.3})});for(const h of[-.012,.012])mt(n,[[i,.44+h,-.135],[i-.025,.44+h,-.07],[i-.032,.44+h,0],[i-.025,.44+h,.07],[i,.44+h,.135]],.004,{density:1.3});mt(n,[[i,.56,.06],[i+.01,.62,.07],[i+.05,.62,.08],[i+.07,.56,.08]],.004,{density:1.2}),_r(n,.011,{at:[i+.072,.548,.08],kind:Fe.GLYPH,bright:1.6,density:3}),si(n,[-.13,.15,0],[-.13+.12,.27,0],.05,.04,.015,{density:1}),_t(n,[-.13+.12,.26,0],[-.13+.13,.34-.03,0],.016,.016,{density:1.2});const r=-.13+.09;_t(n,[r,.34,0],[r+.045,.34,0],.028,.031,{density:1.3}),pt(n,r-.001,.34,0,.024,"x",{kind:Fe.GLYPH,bright:1.3,density:3}),_t(n,[r+.06,.34,-.055],[r+.06,.34,.055],.04,.04,{density:1.2});for(const h of[-.064,.064])_t(n,[r+.06,.34,h],[r+.06,.34,h*1.25],.028,.028,{density:1.3});ze(n,.07,.06,.11,.02,{at:[r+.115,.34+.012,0],density:1.1});for(const h of[-.032,.032])_t(n,[r+.14,.34+.016,h*.8],[r+.24,.34+.04,h],.016,.017,{density:1.3}),_t(n,[r+.24,.34+.04,h],[r+.285,.34+.05,h*1.05],.019,.02,{density:1.4}),pt(n,r+.287,.34+.05,h*1.05,.017,"x",{density:2.2,bright:1.2});const s=.7,o=.12,a=-.13+Math.cos(s)*o,l=-Math.sin(s)*o;si(n,[-.13,.1,0],[a,.1,l],.04,.03,.012,{density:1}),_t(n,[a,.1,l],[a,.3,l],.012,.012,{density:1.2}),n.group({at:[a,0,l],rot:[0,s-Math.PI/2,0]},()=>{ze(n,.05,.075,.05,.012,{at:[0,.34,0],density:1.2}),n.line([[-.018,.34-.026,.026],[.018,.34-.026,.026],[.018,.34+.026,.026],[-.018,.34+.026,.026],[-.018,.34-.026,.026]],{kind:Fe.GLYPH,density:3,bright:1.4}),ze(n,.04,.24,.036,.012,{at:[0,.34+.16,-.004],density:1}),Ke(n,.034,.034,.08,{at:[0,.34+.32,-.006],density:1.1}),Ke(n,.028,.034,.02,{at:[0,.34+.37,-.006],density:1.1});for(let h=0;h<4;h++)pt(n,0,.34+.29+h*.016,-.006,.0345,"y",{density:1.2,bright:.7});Ke(n,.019,.019,.016,{at:[.03,.34+.2,-.004],rot:[0,0,Math.PI/2],density:1.3}),Ke(n,.015,.015,.014,{at:[-.028,.34+.13,-.004],rot:[0,0,Math.PI/2],density:1.3}),un(n,[.02,.34+.25,-.004],[.05,.34+.27,-.004],.004,{density:1.3}),mt(n,[[0,.34+.38,-.006],[0,.34+.42,-.03],[-.03,.34+.38,-.09],[-.05,.12,-.08]],.004,{density:.9})});const c=a+Math.cos(s)*-.024,u=l-Math.sin(s)*-.024;for(let h=0;h<=8;h++){const f=h/8-.5;n.line([[c,.34+f*.044,u],[-.13,.34+f*.03,0]],{kind:Fe.GLYPH,density:4,bright:1.15+.5*(1-Math.abs(f)*2)})}n.line([[-.13,.34-.018,0],[-.13,.34+.018,0]],{kind:Fe.GLYPH,density:8,bright:2})}),n}const ri=(n,e)=>new we(n,e);function nE(){const n=new go("microscope");ze(n,.2,.05,.25,.028,{at:[0,.031,-.005],density:1}),ze(n,.17,.012,.21,.02,{at:[0,.006,-.005],density:.8}),Ke(n,.032,.036,.012,{at:[0,.062,0],density:1.3}),pt(n,0,.069,0,.022,"y",{kind:Fe.GLYPH,bright:1.5,density:3}),pt(n,0,.069,0,.012,"y",{kind:Fe.GLYPH,bright:1.8,density:3}),Ke(n,.02,.02,.012,{at:[.104,.032,.04],rot:[0,0,Math.PI/2],density:1.4,edgeDensity:1.6});for(let u=0;u<12;u++){const h=u/12*Math.PI*2;n.line([[.11,.032+Math.sin(h)*.02,.04+Math.cos(h)*.02],[.098,.032+Math.sin(h)*.02,.04+Math.cos(h)*.02]],{kind:Fe.EDGE,density:1.2,bright:.7})}mt(n,[[0,.03,-.13],[0,.02,-.17],[.03,.006,-.21],[.08,.004,-.24]],.0035,{density:1});const e=new no;e.moveTo(-.118,.05),e.splineThru([ri(-.122,.12),ri(-.132,.19),ri(-.127,.25),ri(-.102,.3),ri(-.062,.334),ri(-.018,.348)]),e.lineTo(-.018,.304),e.splineThru([ri(-.052,.29),ri(-.074,.252),ri(-.081,.19),ri(-.076,.13),ri(-.068,.05)]),e.lineTo(-.118,.05),co(n,e,.056,{rot:[0,-Math.PI/2,0],density:1,curveSeg:8});for(const u of[-1,1]){Ke(n,.03,.03,.016,{at:[u*.037,.105,-.095],rot:[0,0,Math.PI/2],density:1.3,edgeDensity:1.6}),Ke(n,.018,.018,.013,{at:[u*.051,.105,-.095],rot:[0,0,Math.PI/2],density:1.4,edgeDensity:1.6});for(let h=0;h<16;h++){const f=h/16*Math.PI*2,d=.105+Math.sin(f)*.03,v=-.095+Math.cos(f)*.03;n.line([[u*.029,d,v],[u*.045,d,v]],{kind:Fe.EDGE,density:1.2,bright:.75})}}const t=.175;ze(n,.07,.03,.05,.008,{at:[0,t-.012,-.07],density:1}),ze(n,.15,.012,.14,.006,{at:[0,t,0],density:1}),pt(n,0,t+.0065,0,.012,"y",{density:2,bright:1.1}),ze(n,.13,.008,.016,.003,{at:[0,t+.01,-.048],density:1.2}),ze(n,.012,.009,.06,.003,{at:[-.05,t+.011,-.02],density:1.3}),mt(n,[[-.05,t+.012,.009],[-.035,t+.012,.018],[-.018,t+.011,.016]],.0025,{density:1.6}),n.group({at:[.004,t+.0068,0]},()=>{ze(n,.076,.0012,.026,5e-4,{density:1.3,edgeDensity:2.4,edgeBright:1.3}),n.line([[-.011,.001,-.011],[.011,.001,-.011],[.011,.001,.011],[-.011,.001,.011],[-.011,.001,-.011]],{kind:Fe.GLYPH,density:3,bright:1.1});const u=new da(.008,20);u.rotateX(-Math.PI/2),n.surface(u,{at:[0,.0012,0],kind:Fe.GLYPH,bright:.8,density:6,edges:!1,weightFn:(h,f,d)=>.3+Math.abs(Math.sin(h*900+d*400)*Math.cos(d*1100-h*300))}),n.line([[-.036,8e-4,-.012],[-.022,8e-4,-.012],[-.022,8e-4,.012],[-.036,8e-4,.012],[-.036,8e-4,-.012]],{kind:Fe.EDGE,density:2,bright:.9})}),_t(n,[.06,t-.006,.045],[.06,t-.07,.045],.004,.004,{density:1.4}),Ke(n,.013,.013,.016,{at:[.06,t-.045,.045],density:1.5}),Ke(n,.01,.01,.016,{at:[.06,t-.065,.045],density:1.5}),Ke(n,.024,.02,.032,{at:[0,t-.03,0],density:1.3}),pt(n,0,t-.046,0,.026,"y",{density:2,bright:1}),un(n,[.02,t-.04,.01],[.045,t-.04,.03],.002,{density:1.6});for(let u=0;u<10;u++){const h=u/10*Math.PI*2;n.line([[Math.cos(h)*.016,.07,Math.sin(h)*.016],[Math.cos(h)*.006,t+.007,Math.sin(h)*.006]],{kind:Fe.GLYPH,density:1.4,bright:.55})}const i=[0,.244,.021],r=[0,-Math.cos(.26),Math.sin(.26)];n.group({at:i,rot:[-.26,0,0]},()=>{is(n,[[0,.014],[.03,.013],[.044,.004],[.046,-.004],[.04,-.01],[0,-.012]],{density:1.3,seg:36});for(let u=0;u<24;u++){const h=u/24*Math.PI*2;n.line([[Math.cos(h)*.0455,.004,Math.sin(h)*.0455],[Math.cos(h)*.0455,-.004,Math.sin(h)*.0455]],{kind:Fe.EDGE,density:1.4,bright:.8})}});const s=[0,-Math.sin(.26),-Math.cos(.26)],o=[1,0,0],a=[{u:s,len:.034,r:.0105,tip:.0075},{u:o,len:.044,r:.0098,tip:.0055},{u:s.map(u=>-u),len:.05,r:.0098,tip:.0048},{u:o.map(u=>-u),len:.027,r:.0105,tip:.009}],l=Math.tan(.26);for(const u of a){const h=[r[0]+l*u.u[0],r[1]+l*u.u[1],r[2]+l*u.u[2]],f=Math.hypot(h[0],h[1],h[2]);h[0]/=f,h[1]/=f,h[2]/=f;const d=[i[0]+r[0]*.011+u.u[0]*.025,i[1]+r[1]*.011+u.u[1]*.025,i[2]+r[2]*.011+u.u[2]*.025],v=[d[0]+h[0]*u.len*.68,d[1]+h[1]*u.len*.68,d[2]+h[2]*u.len*.68],g=[d[0]+h[0]*u.len,d[1]+h[1]*u.len,d[2]+h[2]*u.len];_t(n,d,v,u.r,u.r,{density:1.5,edgeDensity:1.5}),_t(n,v,g,u.r*.92,u.tip,{density:1.6,edgeDensity:1.5}),d[0]+h[0]*u.len*.5,d[1]+h[1]*u.len*.5,d[2]+h[2]*u.len*.5,_0(n,[d[0]+h[0]*u.len*.5,d[1]+h[1]*u.len*.5,d[2]+h[2]*u.len*.5],h,u.r*1.03,{kind:Fe.GLYPH,bright:1.25,density:2.5})}ze(n,.075,.05,.1,.02,{at:[0,.283,-.012],density:1.1}),ze(n,.06,.03,.07,.014,{at:[0,.32,-.01],density:1.1});const c=[0,Math.sin(.72),Math.cos(.72)];n.group({at:[0,.34,.012],rot:[Math.PI/2-.72,0,0]},()=>{ze(n,.1,.04,.034,.014,{density:1.2})});for(const u of[-1,1]){const h=[u*.032,.343,.02],f=[h[0],h[1]+c[1]*.075,h[2]+c[2]*.075],d=[h[0],h[1]+c[1]*.112,h[2]+c[2]*.112];_t(n,h,f,.0125,.0125,{density:1.4}),_t(n,f,d,.0145,.0145,{density:1.5});const v=[h[0],h[1]+c[1]*.12,h[2]+c[2]*.12];_t(n,d,v,.0155,.0165,{density:1.5}),_0(n,v,c,.0145,{kind:Fe.GLYPH,bright:1.4,density:3})}return _r(n,.006,{at:[.04,.29,.03],kind:Fe.GLYPH,bright:1.4,density:3}),n}const iE=new O,rE=(n,e)=>iE.set(e[0],e[1],e[2]).applyMatrix4(n).toArray();function y0(n,e,t,i){const r=new no,s=-n/2,o=n/2,a=-e/2,l=e/2;return r.moveTo(s+t,a),r.lineTo(o-t,a),r.quadraticCurveTo(o,a,o,a+t),r.lineTo(o,l-i),r.quadraticCurveTo(o,l,o-i,l),r.lineTo(s+i,l),r.quadraticCurveTo(s,l,s,l-i),r.lineTo(s,a+t),r.quadraticCurveTo(s,a,s+t,a),r}function sE(){const n=new go("centrifuge"),e=.53,t=.29;for(const[r,s]of[[-e,-t],[e,-t],[-e,t],[e,t]])ec(n,r,s,{r:.032,w:.024,stem:.02,yaw:r*5-s*3}),ze(n,.04,.48,.04,.008,{at:[r,.335,s],density:.8});ze(n,1.16,.032,.68,.01,{at:[0,.59,0],density:.4});for(const r of[-t,t])ze(n,1.04,.06,.022,.006,{at:[0,.545,r],density:.6});for(const r of[-e,e])ze(n,.022,.06,.56,.006,{at:[r,.545,0],density:.6});ze(n,1.08,.02,.6,.008,{at:[0,.2,0],density:.35});const i=(r,s,o,a,l,c)=>{ze(n,l*.036+.02,.05,a*.036+.02,.01,{at:[r,s+.025,o],density:.8});for(let u=0;u<a;u++)for(let h=0;h<l;h++){const f=r-(l-1)*.036/2+h*.036,d=o-(a-1)*.036/2+u*.036;pt(n,f,s+.051,d,.009,"y",{density:1.6,bright:.9}),(h+u*2)%4!==1&&(Ke(n,.0065,.0065,c,{at:[f,s+.04+c/2,d],open:!0,density:1.2}),Ke(n,.0078,.0078,.016,{at:[f,s+.048+c,d],density:1.4,bright:1.2}))}};return i(.44,.606,.12,2,3,.1),i(-.2,.21,.08,2,6,.1),n.group({at:[-.05,.606,0],s:1.3},()=>{for(const g of[-.17,.17])for(const p of[-.2,.2])Ke(n,.022,.025,.016,{at:[g,.008,p],density:1});co(n,y0(.48,.56,.15,.07),.3-.04,{at:[0,.016+.3/2,0],rot:[-Math.PI/2,0,0],bevel:.02,density:.5,edgeAngle:40});for(const g of[-1,1])for(let p=0;p<6;p++)n.line([[g*(.48/2+.021),.07+p*.026,-.17],[g*(.48/2+.021),.07+p*.026,.06]],{kind:Fe.EDGE,density:1,bright:.55});mt(n,[[.1,.06,-.28],[.12,.03,-.32],[.16,-.01,-.36],[.22,-.02,-.4]],.004,{density:.8});const a=-.03,l=.016+.3+.02;Ke(n,.19,.19,.22,{at:[0,l-.11,a],open:!0,density:.35,edges:!1}),Ww(n,.19,{at:[0,l-.22,a],density:.3}),pt(n,0,l+.001,a,.19,"y",{density:2.8,bright:1.3}),pt(n,0,l+.002,a,.205,"y",{density:2,bright:1}),_t(n,[0,l-.22,a],[0,l-.05,a],.012,.012,{density:1.3}),Ke(n,.022,.026,.03,{at:[0,l-.04,a],density:1.4});const c=.24,u=1.05;for(let g=0;g<5;g++){const p=l-.01+g*.04;n.line([[0,p,a],[0,p+.022,a+.006*g]],{kind:Fe.GLYPH,density:3,bright:.9})}const h=[0,l+c,a+.06];n.group({at:h,rot:[u,0,0]},()=>{n.spinGroup([0,0,0],[0,1,0],.9,()=>{is(n,[[0,-.04],[.05,-.04],[.056,-.02],[.05,.02],[.03,.035],[0,.038]],{density:1.3,seg:36,edges:!1}),Ke(n,.018,.018,.03,{at:[0,.05,0],density:1.5}),pt(n,0,.066,0,.018,"y",{kind:Fe.GLYPH,density:3,bright:1.4}),pt(n,0,-.02,0,.056,"y",{density:2.2,bright:1.2});for(let g=0;g<4;g++){const p=Math.PI/4+g*Math.PI/2,m=Math.cos(p),x=Math.sin(p),_=.15;si(n,[m*.045,0,x*.045],[m*(_-.055),0,x*(_-.055)],.04,.03,.01,{density:1.3});for(const M of[-1,1]){const w=-x*M*.05,P=m*M*.05;si(n,[m*(_-.055),0,x*(_-.055)],[m*_+w,0,x*_+P],.014,.024,.006,{density:1.3}),Ke(n,.009,.009,.014,{at:[m*_+w*1.08,0,x*_+P*1.08],rot:[Math.PI/2,Math.atan2(w,P),0],density:1.4})}const y=m*_,C=x*_;is(n,[[0,-.105],[.03,-.103],[.04,-.09],[.044,-.02],[.046,.012],[.042,.016]],{at:[y,0,C],density:1,seg:28,edges:!1}),pt(n,y,.014,C,.046,"y",{density:2.6,bright:1.3}),pt(n,y,-.06,C,.043,"y",{density:1.2,bright:.8});for(const[M,w]of[[-.016,-.016],[.016,-.016],[-.016,.016],[.016,.016]])Ke(n,.0095,.0095,.02,{at:[y+M,.026,C+w],density:1.5,bright:1.2}),pt(n,y+M,.037,C+w,.007,"y",{kind:Fe.GLYPH,density:3,bright:1.3})}})});const f=[0,l-.004,-.56/2+.01],d=[-1.82,0,0];for(const g of[-.15,.15])Ke(n,.018,.018,.06,{at:[g,f[1],f[2]],rot:[0,0,Math.PI/2],density:1.2});n.group({at:f,rot:d},()=>{n.group({at:[0,.022,.56/2-.01],rot:[-Math.PI/2,0,0]},()=>{co(n,y0(.48-.01,.56-.02,.15,.07),.026,{bevel:.012,density:.6,edgeAngle:40})}),pt(n,0,-.004,.27,.085,"y",{density:2.6,bright:1.25}),pt(n,0,-.004,.27,.068,"y",{density:1.6,bright:.9});const g=.24;n.line([[-g*.8,-.004,.04],[g*.8,-.004,.04],[g*.8,-.004,.46],[-g*.8,-.004,.46],[-g*.8,-.004,.04]],{kind:Fe.EDGE,density:1.3,bright:.75});for(const p of[-.11,.11])ze(n,.03,.03,.02,.006,{at:[p,-.016,.56-.06],density:1.3})});const v=Fl(f,d);for(const g of[-1,1]){const p=rE(v,[g*.215,0,.2]);_t(n,[g*.215,l-.06,-.19],p,.009,.006,{density:1.3})}n.group({at:[0,.2,.56/2+.012],rot:[-.5,0,0]},()=>{ze(n,.4,.13,.03,.014,{density:.8}),Ol(n,.2,.068,.016,{cx:-.08,cy:.014,density:.6}),pr(n,"4000",-.172,-.004,.018,.034,{bright:1.6}),pr(n,"10",-.04,.004,.018,.022,{bright:1.35}),Vs(n,-.172,.04,.018,[.025,.015],.008,{bright:.7});for(let g=0;g<3;g++)uo(n,.05+g*.036,.025,.026,.016,.016,{kind:Fe.EDGE,bright:.85});pt(n,.066,-.026,.016,.012,"z",{kind:Fe.GLYPH,bright:1.5,density:3}),pt(n,.102,-.026,.016,.012,"z",{kind:Fe.GLYPH,bright:1.1,density:3}),Ke(n,.028,.028,.014,{at:[.158,0,.02],rot:[Math.PI/2,0,0],density:1.3,edgeDensity:1.6})})}),n}const il=Math.PI*2;function S0(n,e,t,i,r,s,o,a={}){ze(n,r,s,o,.008,{at:[e,t,i],density:a.density??.7});const l=2;for(let c=0;c<l;c++){const u=t-s*.2+c*s*.32;for(let h=0;h<Math.floor(o/.045);h++){const f=i-o/2+.03+h*.045;for(const d of[-1,1])n.line([[e+d*(r/2+.001),u,f],[e+d*(r/2+.001),u,f+.022]],{kind:Fe.EDGE,density:1.3,bright:.75})}for(let h=0;h<Math.floor(r/.045);h++){const f=e-r/2+.03+h*.045;n.line([[f,u,i+o/2+.001],[f+.022,u,i+o/2+.001]],{kind:Fe.EDGE,density:1.3,bright:.75})}}}function oE(){const n=new go("autoclave"),e=.96,t=.27,i=-.42,r=.36;for(const[f,d]of[[-.27,-.36],[.27,-.36],[-.27,.32],[.27,.32]])ec(n,f,d,{r:.04,w:.03,stem:.022,yaw:f*4+d*2}),ze(n,.045,.56,.045,.006,{at:[f,.39,d],density:.8});for(const f of[-.27,.27])ze(n,.045,.045,.74,.006,{at:[f,.65,-.02],density:.8});for(const f of[-.36,.32])ze(n,.58,.045,.045,.006,{at:[0,.65,f],density:.8});ze(n,.56,.02,.7,.006,{at:[0,.22,-.02],density:.4});const s=new no;s.moveTo(-.24,0),s.lineTo(.24,0);const o=e-.672,a=Math.asin(.24/t);s.lineTo(.24,o-Math.cos(a)*t);for(let f=1;f<16;f++){const d=-a+2*a*f/16;s.lineTo(Math.sin(-d)*t,o-Math.cos(d)*t)}s.lineTo(-.24,o-Math.cos(a)*t),s.lineTo(-.24,0);for(const f of[-.36,.32])co(n,s,.035,{at:[0,.672,f],density:.9});Ke(n,t,t,r-i,{at:[0,e,(i+r)/2],rot:[Math.PI/2,0,0],density:.5,seg:64});for(const f of[i+.04,-.03,r-.06])mt(n,br(0,e,f,t+.006,"z",72),.008,{density:1.3});n.group({at:[0,e,i],rot:[-Math.PI/2,0,0]},()=>{is(n,[[0,.07],[.1,.062],[.18,.045],[.24,.022],[t,0]],{density:.6,seg:48,edges:!1})}),Ke(n,t+.03,t+.03,.045,{at:[0,e,r+.012],rot:[Math.PI/2,0,0],density:.9,seg:64});const l=r+.06;Ke(n,t+.02,t+.02,.045,{at:[0,e,l],rot:[Math.PI/2,0,0],density:.9,seg:64}),n.group({at:[0,e,l+.022],rot:[Math.PI/2,0,0]},()=>{is(n,[[0,.05],[.12,.044],[.21,.026],[t+.01,0]],{density:.45,seg:48,edges:!1})});for(let f=0;f<8;f++){const d=f/8*il+il/16,v=Math.cos(d),g=Math.sin(d);n.group({at:[v*(t+.03),e+g*(t+.03),l-.01],rot:[0,0,d]},()=>{ze(n,.07,.034,.075,.008,{density:1.2})}),un(n,[v*.06,e+g*.06,l+.06],[v*(t-.01),e+g*(t-.01),l+.035],.009,{density:1.3})}const c=l+.11;_t(n,[0,e,l+.05],[0,e,c+.02],.026,.026,{density:1.3}),Ke(n,.05,.05,.05,{at:[0,e,c],rot:[Math.PI/2,0,0],density:1.6,edgeDensity:1.8}),pt(n,0,e,c+.026,.03,"z",{kind:Fe.GLYPH,density:3,bright:1.4}),mt(n,br(0,e,c,.175,"z",96),.016,{density:2.4,bright:1.45});for(let f=0;f<6;f++){const d=f/6*il+il/12,v=Math.cos(d),g=Math.sin(d);un(n,[v*.048,e+g*.048,c],[v*.235,e+g*.235,c],.011,{density:2.2,bright:1.4}),_r(n,.024,{at:[v*.25,e+g*.25,c],density:2.2,bright:1.45})}for(const f of[-.13,.13])Ke(n,.022,.022,.07,{at:[-t-.07,e+f,r+.02],density:1.2}),si(n,[-t-.07,e+f,r+.02],[-t+.03,e+f,l],.03,.04,.01,{density:1.1});_t(n,[-t-.07,e-.18,r+.02],[-t-.07,e+.18,r+.02],.009,.009,{density:1.3});const u=e+t;_t(n,[0,u-.01,.22],[0,u+.11,.22],.013,.013,{density:1.3}),n.group({at:[0,u+.19,.235],rot:[Math.PI/2,0,0]},()=>{Ke(n,.09,.09,.04,{density:1,seg:48})}),n.group({at:[0,u+.19,.256],s:1.2},()=>{pt(n,0,0,0,.068,"z",{density:2.6,bright:1.3});for(let d=0;d<=20;d++){const v=Math.PI*1.25-d/20*Math.PI*1.5,g=d%5===0?.046:.052;n.line([[Math.cos(v)*g,Math.sin(v)*g,0],[Math.cos(v)*.06,Math.sin(v)*.06,0]],{kind:Fe.GLYPH,density:3,bright:1.2})}const f=Math.PI*1.25-.62*Math.PI*1.5;n.line([[-Math.cos(f)*.012,-Math.sin(f)*.012,.002],[Math.cos(f)*.055,Math.sin(f)*.055,.002]],{kind:Fe.GLYPH,density:6,bright:1.8}),_r(n,.007,{at:[0,0,.003],kind:Fe.GLYPH,bright:1.5,density:3})}),mt(n,[[0,u+.06,.22],[.06,u+.06,.2],[.12,u+.05,.1],[.12,u,.06]],.01,{density:1.2}),_t(n,[.12,u-.02,.06],[.12,u+.1,.06],.022,.018,{density:1.3}),un(n,[.12,u+.1,.06],[.12,u+.11,-.08],.006,{density:1.4}),_r(n,.024,{at:[.12,u+.11,-.09],density:1.3}),_t(n,[-.13,u-.03,.08],[-.13,u+.08,.08],.018,.018,{density:1.3}),un(n,[-.18,u+.085,.08],[-.08,u+.085,.08],.008,{density:1.4}),mt(n,[[-.13,u+.03,.08],[-.2,u+.03,.04],[-.24,u-.02,-.02],[-.27,e+.1,-.06]],.009,{density:1});const h=t+.04;for(const f of[e-.1,e+.1])un(n,[t-.01,f,.12],[h,f,.12],.008,{density:1.3});return Ke(n,.012,.012,.2,{at:[h,e,.12],open:!0,density:1.2}),Ke(n,.009,.009,.09,{at:[h,e-.05,.12],kind:Fe.FLUID,density:2.5,edges:!1}),_t(n,[0,e-t+.01,.1],[0,e-t-.12,.1],.014,.014,{density:1.2}),un(n,[0,e-t-.09,.1],[.09,e-t-.09,.14],.007,{density:1.4}),n.group({at:[0,.54,.38]},()=>{ze(n,.44,.18,.08,.016,{density:.75});const f=.041;Ol(n,.13,.06,f,{cx:-.12,cy:.035,density:.6}),pr(n,"121",-.175,.016,f+.002,.034,{bright:1.5}),Ol(n,.1,.06,f,{cx:.03,cy:.035,density:.6}),pr(n,"15",0,.016,f+.002,.034,{bright:1.4});for(let d=0;d<4;d++)pt(n,-.17+d*.045,-.045,f,.011,"z",{kind:Fe.GLYPH,bright:1.3+(d===1?.4:0),density:3});for(let d=0;d<2;d++)uo(n,.04+d*.05,-.045,.035,.022,f,{kind:Fe.EDGE,bright:.9});Ke(n,.032,.032,.02,{at:[.16,0,f+.008],rot:[Math.PI/2,0,0],density:1.3,edgeDensity:1.6})}),mt(n,[[.18,.6,.34],[.22,.66,.2],[.2,e-t+.02,0]],.006,{density:.9}),S0(n,0,.26,-.04,.42,.055,.32,{density:.7}),S0(n,.01,.318,-.03,.4,.055,.3,{density:.7}),n}const rs=[{id:"monitor",name:"Vitals monitor",build:jw,height:2.5,maxSpan:3.2,yaw:-.3,gain:1,lineK:.03,edgeK:.022,presence:1.44},{id:"dental",name:"Dental chair",build:eE,height:2.4,maxSpan:3.3,yaw:-.15,gain:1,lineK:.03,edgeK:.025,presence:1.6},{id:"slitlamp",name:"Slit lamp",build:tE,height:2.5,maxSpan:3.2,yaw:-.2,gain:1,lineK:.03,edgeK:.025,presence:1.66},{id:"microscope",name:"Lab microscope",build:nE,height:2.6,maxSpan:3.2,yaw:-.55,gain:1,lineK:.03,edgeK:.021,presence:1.26},{id:"centrifuge",name:"Lab centrifuge",build:sE,height:2.4,maxSpan:3.2,yaw:-.1,gain:1,lineK:.03,edgeK:.022,presence:1.55},{id:"autoclave",name:"Autoclave",build:oE,height:2.3,maxSpan:3.3,yaw:.42,gain:1,lineK:.03,edgeK:.024,presence:1.78}];function aE(n){const e=new Float32Array(n*4),t=new Float32Array(n*4);for(let i=0;i<n;i++)e[i*4+3]=Fe.VORTEX,t[i*4+3]=1;return{pos:e,nrm:t}}const lE=`
uniform highp sampler2DArray uPos;
uniform highp sampler2DArray uNrm;
uniform int uTexW;
uniform int uLayerA;
uniform int uLayerB;
uniform int uLayerC;
uniform float uMixAB;
uniform float uMixC;
uniform float uRingF;
uniform float uRingC;
uniform float uRingPhase;
uniform float uTime;
uniform float uHeight;
uniform float uSize;
uniform float uViewH;
uniform float uIntensity;
uniform float uGlitch;
uniform float uMotion;
uniform float uSizeComp;
uniform float uSweep;
uniform float uScan;
uniform float uDrift;
uniform float uFace;
uniform float uFlow;
uniform vec4 uSpinC[LAYERS];
uniform vec4 uSpinD[LAYERS];

varying float vBright;
varying float vTint;

float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float smoother(float x) { return x * x * x * (x * (x * 6.0 - 15.0) + 10.0); }

// Ring transition: the old shape leaves top-first, the new one is written bottom-up, with a
// little random stagger.
float ringU(float p, float hFrom, float hTo, vec3 s) {
  float leave = 0.3 * (1.0 - clamp(hFrom, 0.0, 1.0)) + 0.08 * s.x;
  float arrive = 0.6 + 0.3 * clamp(hTo, 0.0, 1.0) + 0.08 * s.y;
  return clamp((p - leave) / (arrive - leave), 0.0, 1.0);
}

// Direct transition: a front climbs from the base to the top; each particle is in flight while the
// front passes the mean of its old and new heights.
float directU(float p, float hFrom, float hTo, vec3 s) {
  float h = clamp(0.5 * (hFrom + hTo), 0.0, 1.0);
  return clamp((p - (0.56 * h + 0.06 * s.x)) / 0.38, 0.0, 1.0);
}

float localU(float p, float hFrom, float hTo, vec3 s, float ring) {
  return ring > 0.5 ? ringU(p, hFrom, hTo, s) : directU(p, hFrom, hTo, s);
}

float bump(float u) { return pow(sin(3.14159265 * u), 0.7); }

// The ring vortex: a stack of thin counter-rotating rings plus loose dust, derived from the
// particle's seed. Dormant particles sit on it; the first decode writes the machine out of it.
vec3 ringPos(vec3 s) {
  float slices = 7.0;
  float k = floor(s.x * slices);
  float dir = mod(k, 2.0) * 2.0 - 1.0;
  float ringY = uHeight * (0.1 + 0.8 * (k + 0.5) / slices);
  float ringR = 0.62 + 0.4 * fract(k * 0.618 + 0.21) + (s.y - 0.5) * 0.035;
  float ang = s.y * 6.2831853 + dir * uRingPhase * (1.0 + 0.22 * k);
  vec3 ring = vec3(cos(ang) * ringR, ringY + (s.z - 0.5) * 0.03, sin(ang) * ringR);
  float lr = 0.25 + 1.25 * fract(s.z * 7.13);
  float la = s.y * 6.2831853 + dir * uRingPhase * 0.45;
  vec3 dust = vec3(cos(la) * lr, uHeight * (0.06 + 0.9 * s.x), sin(la) * lr);
  return mix(ring, dust, step(0.74, s.z));
}

// Spinning parts (param 0.75 on a surface / edge / line / glyph particle) turn about their layer's
// spin axis: Rodrigues rotation of the stored position and normal.
vec3 spinRot(vec3 v, vec3 k, float c, float s) { return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c); }
void spinPart(inout vec4 p, inout vec4 n, int layer) {
  vec4 sc = uSpinC[layer];
  float kind = floor(p.w);
  if (sc.w == 0.0 || kind > 5.5 || abs(kind - 4.0) < 0.5 || abs(p.w - kind - 0.75) > 0.02) return;
  vec3 k = uSpinD[layer].xyz;
  float ang = uTime * sc.w * (0.35 + 0.65 * uMotion);
  float c = cos(ang);
  float s = sin(ang);
  p.xyz = sc.xyz + spinRot(p.xyz - sc.xyz, k, c, s);
  n.xyz = spinRot(n.xyz, k, c, s);
}

// Dormant (vortex-kind) particles live on the ring vortex instead of a stored position.
vec3 source(vec4 p, vec3 s) {
  return abs(floor(p.w) - 8.0) < 0.5 ? ringPos(s) : p.xyz;
}

// c = 0 settled on the machine, 1 fully airborne on the ring vortex.
vec3 swirl(vec3 p, float c, vec3 s) {
  if (c <= 0.0) return p;
  vec3 q = mix(p, ringPos(s), smoothstep(0.0, 0.72, c));
  // small per-particle shimmer (hashed phases: s.y also sets the ring angle, so using it directly
  // would ripple every ring in coherent waves)
  float h1 = hash11(s.x * 811.0 + s.y * 997.0);
  float h2 = hash11(s.y * 613.0 + s.z * 409.0);
  q += c * 0.018 * vec3(sin(uTime * 1.7 + h1 * 40.0), sin(uTime * 1.3 + h2 * 40.0), cos(uTime * 1.9 + h1 * h2 * 60.0));
  return q;
}

// Analytic curl of a sine vector potential: divergence-free, so neighbouring particles flow
// together in coherent streams instead of scattering.
vec3 curlOctave(vec3 p, vec3 pa, vec3 pb) {
  vec3 A = p + pa;
  vec3 B = p + pb;
  vec3 sA = sin(A); vec3 cA = cos(A); vec3 sB = sin(B); vec3 cB = cos(B);
  return -vec3(sA.x * sB.y + cA.z * cB.x, sA.y * sB.z + cA.x * cB.y, sA.z * sB.x + cA.y * cB.z);
}
vec3 flowField(vec3 p) {
  return 0.36 * curlOctave(p * 1.5, vec3(0.0, 1.7, 4.1), vec3(2.3, 5.2, 0.9))
       + 0.14 * curlOctave(p * 3.4 + 11.0, vec3(3.1, 0.4, 2.6), vec3(1.2, 4.4, 5.9));
}

// silhouette term from the sampled surface normal (edges/lines have no normal -> always lit)
float rimOf(vec3 n, vec3 V) {
  float nl = length(n);
  float facing = nl > 0.05 ? abs(dot(n / nl, V)) : 0.0;
  float r = 1.0 - facing;
  return r * r;
}

// per-kind look: x = brightness, y = point size, z = mint tint
vec3 look(float w, float rim, vec3 pos) {
  float kind = floor(w);
  float param = w - kind;
  float br;
  float size = 1.0;
  float tint = 0.3;
  if (kind < 0.5) { // surface: lit body with a brighter silhouette
    br = uFace + (1.05 - uFace) * pow(rim, 0.8);
  } else if (kind < 1.5) { // edge
    br = 0.92;
    size = 0.82;
    tint = 0.14;
  } else if (kind < 2.5) { // tube / cable / hose
    br = 0.42 + 0.75 * rim;
    size = 0.9;
  } else if (kind < 3.5) { // display glass
    br = 0.3 * (0.75 + 0.25 * sin(pos.y * 700.0));
    tint = 0.6;
    size = 0.9;
  } else if (kind < 4.5) { // swept waveform
    float head = fract(uTime / uSweep);
    float behind = fract(head - param);
    // erase gap ahead of the write head, bright fresh trace fading to a dim persisted line
    br = behind > 0.92 ? 0.0 : 0.22 + 2.2 * exp(-behind * 7.0) + 1.5 * exp(-behind * 60.0);
    tint = 0.15 + 0.7 * exp(-behind * 5.0);
    size = 0.92;
  } else if (kind < 5.5) { // numerics, screen image
    br = 1.1;
    size = 0.85;
    tint = 0.22;
  } else if (kind < 6.5) { // fluid
    br = 0.32 + 0.22 * sin(uTime * 1.8 + pos.x * 35.0 + pos.z * 27.0);
    tint = 0.75;
  } else if (kind < 7.5) { // drip
    br = 1.3;
    tint = 0.6;
  } else { // dormant ring vortex
    br = 0.42;
    tint = 0.45;
  }
  return vec3(br, size, tint);
}

void main() {
  vec3 s = position; // per-particle random seeds in [0,1)
  ivec2 st = ivec2(gl_VertexID % uTexW, gl_VertexID / uTexW);
  vec4 pA = texelFetch(uPos, ivec3(st, uLayerA), 0);
  vec4 pB = texelFetch(uPos, ivec3(st, uLayerB), 0);
  vec4 pC = texelFetch(uPos, ivec3(st, uLayerC), 0);
  vec4 nA = texelFetch(uNrm, ivec3(st, uLayerA), 0);
  vec4 nB = texelFetch(uNrm, ivec3(st, uLayerB), 0);
  vec4 nC = texelFetch(uNrm, ivec3(st, uLayerC), 0);
  spinPart(pA, nA, uLayerA);
  spinPart(pB, nB, uLayerB);
  spinPart(pC, nC, uLayerC);
  vec3 a = source(pA, s);
  vec3 b = source(pB, s);
  vec3 c = source(pC, s);

  float uF = localU(uMixAB, a.y / uHeight, b.y / uHeight, s, uRingF);
  float eF = smoother(uF);
  vec3 baseF = mix(a, b, eF);
  vec3 nF = mix(nA.xyz, nB.xyz, eF);
  float briF = mix(nA.w, nB.w, eF);
  float flyF = bump(uF);
  float wF = eF > 0.5 ? pB.w : pA.w;

  float uC = localU(uMixC, baseF.y / uHeight, c.y / uHeight, s, uRingC);
  float eC = smoother(uC);
  vec3 base = mix(baseF, c, eC);
  float bri = mix(briF, nC.w, eC);
  float flyC = bump(uC);
  // airborne on the ring vortex / in direct flight
  float cloud = max(flyC * uRingC, (1.0 - eC) * flyF * uRingF);
  float travel = max(flyC * (1.0 - uRingC), (1.0 - eC) * flyF * (1.0 - uRingF));
  float wDom = eC > 0.5 ? pC.w : wF;
  float kind = floor(wDom);
  float param = wDom - kind;
  float settled = 1.0 - max(cloud, travel);

  vec3 pos = swirl(base, cloud, s);
  if (travel > 0.0) {
    // detour through a slowly drifting curl field (sampled at the midpoint of the trip, so each
    // particle's path is a smooth arc), plus a little per-particle scatter
    vec3 mid = 0.5 * (baseF + c);
    vec3 jit = vec3(hash11(s.x * 917.0 + 3.1), hash11(s.y * 613.0 + 7.7), hash11(s.z * 733.0 + 1.3)) - 0.5;
    pos += (flowField(mid + vec3(0.0, uTime * 0.16, 0.0)) * uFlow + jit * 0.07) * travel;
  }

  // a few particles drift upward and fade, then re-form in place
  // (weighted toward the top of the machine, like heat shimmer off the hologram)
  float hN = clamp(base.y / uHeight, 0.0, 1.0);
  float isDrift = step(s.z, uDrift * (0.15 + 1.7 * hN * hN)) * step(kind, 2.5) * settled;
  float dc = fract(uTime * (0.04 + 0.06 * s.x) + s.y * 7.0);
  pos.y += isDrift * dc * (0.3 + 0.9 * s.x) * (0.3 + 0.7 * uMotion);
  pos.xz += isDrift * dc * dc * 0.14 * vec2(sin(uTime * 0.7 + s.x * 20.0), cos(uTime * 0.6 + s.y * 20.0));
  float driftA = mix(1.0, (1.0 - dc) * smoothstep(0.0, 0.05, dc), isDrift);

  // falling drop inside a drip chamber
  if (abs(kind - 7.0) < 0.5) {
    float ph = fract(uTime / 1.4 + param);
    pos.y -= ph * ph * 0.06 * settled;
  }

  // digital glitch slices while decoding (tinted mint)
  float gb = floor(pos.y * 11.0 + floor(uTime * 15.0) * 1.37);
  float gl = step(0.82, hash11(gb * 1.7 + 0.3)) * uGlitch * uMotion;
  pos.x += gl * (hash11(gb + 7.1) - 0.5) * 0.28;

  vec4 mv = modelViewMatrix * vec4(pos, 1.0);
  gl_Position = projectionMatrix * mv;

  // look of the machine the particle is leaving and of the one it is joining, blended in flight
  vec3 V = normalize(-mv.xyz);
  vec3 lk = mix(look(wF, rimOf(normalMatrix * nF, V), pos), look(pC.w, rimOf(normalMatrix * nC.xyz, V), pos), eC);
  float br = lk.x;
  float size = lk.y;
  float tint = lk.z;

  // per-particle flicker + rare twinkle
  float fl = 0.84 + 0.16 * sin(uTime * (2.0 + 7.0 * s.x) + s.y * 6.2831);
  float tw = pow(max(0.0, sin(uTime * (0.5 + 1.5 * s.z) + s.x * 50.0)), 48.0) * 1.8;
  fl = mix(1.0, fl, uMotion) + tw * uMotion;

  // slow vertical scan band
  float scanY = mod(uTime * 0.21, uHeight + 1.6) - 0.8;
  float band = exp(-pow((base.y - scanY) * 7.0, 2.0)) * settled * uScan;

  // arrival flash as each particle locks into the new machine
  float flash = sin(3.14159265 * clamp((uC - 0.78) / 0.22, 0.0, 1.0));

  // direct morph: a thin mint scan line rides the climbing front
  float front = (uMixC - 0.22) / 0.56;
  float scanOn = (1.0 - uRingC) * step(0.001, uMixC) * step(uMixC, 0.999);
  float scanLine = scanOn * exp(-pow((pos.y / uHeight - front) * 16.0, 2.0));

  br = mix(br, 0.42, cloud) + flash * 1.1 + band * 0.85 + scanLine * 1.3 + travel * 0.2 + gl * 0.6;
  tint = clamp(tint + cloud * 0.4 + band * 0.6 + flash * 0.5 + scanLine * 0.75 + travel * 0.3 + gl * 1.5, 0.0, 1.0);

  // depth cue: the far side of the machine is dimmer
  vec4 cmv = modelViewMatrix * vec4(0.0, uHeight * 0.5, 0.0, 1.0);
  float depthK = clamp(1.0 + (mv.z - cmv.z) * 0.22, 0.5, 1.3);

  float bright = br * bri * fl * depthK * driftA * uIntensity;
  size *= 0.78 + 0.44 * hash11(s.x * 397.0 + s.z * 211.0); // organic size variance
  float ps = uSize * size * uSizeComp * (1.0 + 0.2 * cloud + isDrift * 0.7) * projectionMatrix[1][1] * uViewH / max(0.05, -mv.z);
  // below ~1 px, keep the point but scale its energy by area so the hologram's overall
  // brightness does not depend on how large it is on screen
  if (ps < 1.25) { bright *= (ps / 1.25) * (ps / 1.25); ps = 1.25; }
  gl_PointSize = min(ps, 30.0);
  vBright = bright;
  vTint = tint;
}
`,cE=`
uniform vec3 uMint;
varying float vBright;
varying float vTint;

void main() {
  vec2 c = gl_PointCoord * 2.0 - 1.0;
  float r2 = dot(c, c);
  if (r2 > 1.0) discard;
  float core = exp(-r2 * 4.0);
  float shape = core * 0.88 + (1.0 - r2) * 0.12;
  vec3 col = mix(vec3(1.0), uMint, clamp(vTint * (1.0 - core * 0.65), 0.0, 1.0));
  gl_FragColor = vec4(col * vBright, shape);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}
`,uE=`
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
`,hE=`
uniform vec3 uColor;
uniform float uOpacity;
varying vec2 vUv;
void main() {
  vec2 p = (vUv - 0.5) * 2.0;
  float r = length(p * vec2(1.0, 0.82));
  float a = 1.0 - smoothstep(0.12, 1.0, r);
  gl_FragColor = vec4(uColor, a * a * uOpacity);
  #include <colorspace_fragment>
}
`,Fs={high:8e4,mid:35e3,low:15e3},Fr=512,en=rs.length,di=rs.length+1,Do=2.5,fE="#7CF5C8",lu=rs.length,dE=rs.map(n=>n.presence??1),pE=.6,mE=.5,gE=[.74,.74,.68,.48,.1,.07],vE=.85,_E=[1.24,1.27,1.31,1.2,1.02,1],M0=n=>{const e=typeof n=="string"?n:n&&n.tier;return Fs[e]?e:"high"};function b0(n,e){const t=n.length,i=(e%t+t)%t,r=Math.floor(i),s=i-r;return n[r]+(n[(r+1)%t]-n[r])*s}const xE=(n,e,t)=>e+((n-e)%t+t*1.5)%t-t/2;function yE({renderer:n,bus:e,quality:t="high",size:i=.0105,sway:r=!0,intensity:s=1,gateOnIntro:o=!0,aura:a=!0}={}){const l=typeof matchMedia=="function"&&matchMedia("(prefers-reduced-motion: reduce)").matches;let c=M0(t),u=Fs[c],h=Math.ceil(u/Fr),f,d,v,g,p;const m=new Array(di).fill(!1),x=new Array(di).fill(0),_=new Array(di).fill(1);let y=null,C=!1;const M={presence:dE.slice(),aura:gE.slice(),auraOn:a,sizeK:pE,gainK:mE,exploreSize:vE,exploreDayGain:_E.slice()},w={uPos:{value:null},uNrm:{value:null},uTexW:{value:Fr},uLayerA:{value:en},uLayerB:{value:en},uLayerC:{value:en},uMixAB:{value:0},uMixC:{value:1},uRingF:{value:1},uRingC:{value:1},uRingPhase:{value:0},uTime:{value:0},uHeight:{value:Do},uSize:{value:i},uViewH:{value:450},uIntensity:{value:1},uGlitch:{value:0},uMotion:{value:l?.25:1},uSizeComp:{value:1},uSweep:{value:3.6},uScan:{value:1},uDrift:{value:.012},uFace:{value:.42},uFlow:{value:l?.12:.3},uMint:{value:new st(fE)},uSpinC:{value:Array.from({length:di},()=>new Ct)},uSpinD:{value:Array.from({length:di},()=>new Ct(0,1,0,0))}},P=new xt({uniforms:w,vertexShader:lE,fragmentShader:cE,defines:{LAYERS:di},transparent:!0,depthWrite:!1,depthTest:!0,blending:Zr});function I(){h=Math.ceil(u/Fr);const ie=Fr*h*4;f=new Float32Array(ie*di),d=new Float32Array(ie*di),v?.dispose(),g?.dispose(),v=new El(f,Fr,h,di),g=new El(d,Fr,h,di);for(const _e of[v,g])_e.format=Hn,_e.type=_i,_e.minFilter=dn,_e.magFilter=dn,_e.generateMipmaps=!1;w.uPos.value=v,w.uNrm.value=g;const Q=new Float32Array(u*3),le=ou(4242);for(let _e=0;_e<Q.length;_e++)Q[_e]=le();const Te=new Et;Te.setAttribute("position",new kt(Q,3)),Te.setDrawRange(0,u),p&&p.dispose(),p=Te,ce&&(ce.geometry=p),m.fill(!1)}function S(ie){if(m[ie]||C)return;const Q=performance.now();let le;if(ie===en)le=aE(u);else{const _e=rs[ie],qe=_e.build();le=qe.sample(u,ou(1e3+ie*131),{lineK:_e.lineK,edgeK:_e.edgeK});const rt=kw(le.pos,le.nrm,u,{height:_e.height,maxSpan:_e.maxSpan,yaw:_e.yaw,pivot:_e.pivot});if(qe.spin){const Je=rt.point(qe.spin.c),yt=rt.dir(qe.spin.d);w.uSpinC.value[ie].set(Je[0],Je[1],Je[2],qe.spin.w),w.uSpinD.value[ie].set(yt[0],yt[1],yt[2],0)}qe.dispose();const Lt=Bw(le.pos,u,{ref:88*(u/Fs.high)})*(_e.gain??1);_[ie]=Lt;for(let Je=0;Je<u;Je++)le.nrm[Je*4+3]*=Lt}ie!==en&&Hw(le.pos,le.nrm,u,ou(9e3+ie));const Te=ie*Fr*h*4;f.set(le.pos,Te),d.set(le.nrm,Te),v.addLayerUpdate(ie),g.addLayerUpdate(ie),v.needsUpdate=!0,g.needsUpdate=!0,m[ie]=!0,x[ie]=performance.now()-Q}function b(){if(C)return;const ie=m.findIndex(le=>!le);if(ie<0){N();return}const Q=()=>{y=null,S(ie),b()};typeof requestIdleCallback=="function"?y={id:requestIdleCallback(Q,{timeout:1500}),idle:!0}:y={id:setTimeout(Q,40),idle:!1}}let N,R;const H=()=>{R=new Promise(ie=>{N=ie})};H();const T=new Zn;T.name="equipment-hologram";const k=new Zn,Z=new Zn,K=new Zn,pe=new Zn;K.position.y=Do*.5,pe.position.y=-Do*.5,T.add(k),k.add(Z),Z.add(K),K.add(pe);let ce=null;I(),ce=new Yl(p,P),ce.frustumCulled=!1,ce.renderOrder=10,pe.add(ce);let W=null;ce.onBeforeRender=(ie,Q,le)=>{W=le};const re=new xt({uniforms:{uColor:{value:new st("#07090a")},uOpacity:{value:0}},vertexShader:uE,fragmentShader:hE,transparent:!0,depthWrite:!1,depthTest:!0}),Ae=new as(6.8,6),ee=new Gt(Ae,re);ee.name="equipment-hologram-aura",ee.renderOrder=9,ee.frustumCulled=!1,ee.visible=!1,T.add(ee),S(en),b();const F={A:en,B:en,C:en,mixAB:0,mixC:1,ringF:1,ringC:1,active:!1,target:en,ringPhase:0,ringSpeed:.3,explore:0,dim:1,index:-1,presence:1,aura:0,shift:0};let xe=null,G=null,he=null,me=null,fe=null,De=null;function se(){w.uLayerA.value=F.A,w.uLayerB.value=F.B,w.uLayerC.value=F.C,w.uMixAB.value=F.mixAB,w.uMixC.value=F.mixC,w.uRingF.value=F.ringF,w.uRingC.value=F.ringC}function U(){F.A=F.B=F.C,F.mixAB=0,F.mixC=1,F.ringF=F.ringC,F.active=!1,se()}function Se(ie,Q={}){if(C)return;const le=rs.length;if(ie=((Math.round(Number(ie))||0)%le+le)%le,F.index=ie,m[ie]||S(ie),xe=null,F.target===ie)return;const Te=!F.active&&F.C===en;let _e=Q.duration??(Te?1.6:1.3);if(l&&(_e=Math.min(_e,.9)),G?.kill(),he?.kill(),_e<=.001){F.C=ie,F.ringC=0,F.target=ie,U(),w.uGlitch.value=0;return}F.active?(F.A!==F.B&&(F.A=F.mixAB>.5?F.B:F.A),F.B=F.C,F.mixAB=F.mixC):(F.A=F.B=F.C,F.mixAB=0),F.ringF=F.ringC,F.ringC=Te?1:0,F.C=ie,F.mixC=0,F.target=ie,F.active=!0,se();const qe=w.uGlitch;Te?(G=Ht.to(F,{mixC:1,duration:_e,ease:"none",onUpdate:se,onComplete:U}),he=Ht.timeline().to(qe,{value:1,duration:.1,ease:"power1.out"}).to(qe,{value:0,duration:_e*.35,ease:"power2.in"}).to(qe,{value:.55,duration:.06},_e*.8).to(qe,{value:0,duration:.25})):(G=Ht.to(F,{mixC:1,duration:_e,ease:"power2.inOut",onUpdate:se,onComplete:U}),he=Ht.timeline().to(qe,{value:.3,duration:.08,ease:"power1.out"}).to(qe,{value:0,duration:.3,ease:"power2.in"}).to(qe,{value:.75,duration:.05},_e*.8).to(qe,{value:0,duration:.2,ease:"power1.in"}))}function ye(ie,Q,le,Te=null,_e=null){S(ie),S(Q),G?.kill(),he?.kill(),F.A=F.B=ie,F.mixAB=0,F.C=Q,F.mixC=le,F.ringC=_e==null?ie===en?1:0:_e?1:0,F.ringF=F.ringC,F.active=!1,Te!=null&&(F.ringPhase=Te,xe=Te),F.target=Q,Q!==en&&(F.index=Q),se()}function ge(ie){me?.kill(),me=Ht.to(F,{explore:ie,duration:l?.4:1.1,ease:"power3.inOut"})}function B(ie){fe?.kill(),fe=Ht.to(F,{dim:ie,duration:.8,ease:"power2.out"})}function q(ie,Q=l?.8:2.6){if(De?.kill(),F.shift=xE(F.shift,ie,lu),Q<=0){F.shift=ie;return}De=Ht.to(F,{shift:ie,duration:Q,ease:"power2.inOut"})}function V(ie){const Q=M0(ie),le=Fs[Q];if(c=Q,le>u){const Te=F.target;u=le,y&&z(),H(),I(),S(en),Te!==en&&S(Te),G?.kill(),F.C=Te,U(),b()}p.setDrawRange(0,le),w.uSizeComp.value=Math.pow(Fs.high/le,.33),A=Math.pow(Fs.high/le,.2)}let A=1,E=s;function z(){y&&(y.idle?cancelIdleCallback(y.id):clearTimeout(y.id),y=null)}const $={x:0,y:0},ne={x:0,y:0};let te=0,ve=0;function ue(ie,Q){$.x=Math.max(-1,Math.min(1,Number(ie)||0)),$.y=Math.max(-1,Math.min(1,Number(Q)||0))}const Me=new we,Re=new O,de=new O,Ee=new Hi,Ne=new Hi;function Ve(ie,Q){if(C)return;ie=Math.min(Math.max(ie||0,0),.1),w.uTime.value=Q,n&&(n.getDrawingBufferSize(Me),w.uViewH.value=Me.y*.5);const le=1-Math.exp(-ie*2.4);ne.x+=($.x-ne.x)*le,ne.y+=($.y-ne.y)*le,ve+=(te-ve)*(1-Math.exp(-ie*3));const _e=r?(l?.18:.55)*Math.sin(Q*Math.PI*2/32):0;pe.rotation.y=_e+ne.x*.3+ve,K.rotation.x=ne.y*.09,K.rotation.z=-ne.x*.025;const qe=(F.active?1.25:.32)*(l?.4:1);F.ringSpeed+=(qe-F.ringSpeed)*(1-Math.exp(-ie*3)),xe==null&&(F.ringPhase+=F.ringSpeed*ie),w.uRingPhase.value=F.ringPhase;const rt=F.explore,Lt=F.target!==en,Je=Lt?1+((M.presence[F.target]??1)-1)*(1-rt):1;F.presence+=(Je-F.presence)*(1-Math.exp(-ie*3.2));const yt=F.presence;if(k.scale.setScalar(yt),W&&rt>1e-4){T.updateWorldMatrix(!0,!1),Re.setFromMatrixPosition(W.matrixWorld),T.worldToLocal(Re),Re.y-=Do*.5;const Dn=Re.length();Re.normalize().multiplyScalar(Dn*.16*rt/yt),Z.position.copy(Re)}else Z.position.set(0,0,0);Z.scale.setScalar(1+.06*rt),w.uSize.value=i*Math.pow(yt,M.sizeK)*(1+(M.exploreSize-1)*rt);const Jt=1+(b0(M.exploreDayGain,F.shift)/(M.exploreSize*M.exploreSize)*1.35-1)*rt;w.uIntensity.value=E*A*Math.pow(yt,M.gainK)*Jt*F.dim,w.uScan.value=1+.6*rt,F.aura+=((Lt&&M.auraOn?1:0)-F.aura)*(1-Math.exp(-ie*1.2));const Ti=b0(M.aura,F.shift)*F.aura;if(re.uniforms.uOpacity.value=Ti,ee.visible=Ti>.002&&!!W,ee.visible){const Dn=Do*.5*yt;T.updateWorldMatrix(!0,!1),Re.setFromMatrixPosition(W.matrixWorld),T.worldToLocal(Re),de.set(0,Dn,0).sub(Re).normalize(),ee.position.set(0,Dn,0).addScaledVector(de,1.2),ee.scale.setScalar(Math.sqrt(yt)),T.getWorldQuaternion(Ee),W.getWorldQuaternion(Ne),ee.quaternion.copy(Ee.invert().multiply(Ne))}}const Pe=[],Xe=(ie,Q)=>{e&&(e.on(ie,Q),Pe.push([ie,Q]))};let We=!o,dt=0;Xe("step:change",ie=>{const Q=ie&&ie.index!=null?ie.index:0;q(Math.max(0,Math.min(lu-1,Math.round(Number(Q))||0))),We||F.target!==en?Se(Q):dt=Q}),Xe("intro:enter",()=>{We=!0,F.target===en&&Se(F.index>=0?F.index:dt)}),Xe("explore:open",()=>ge(1)),Xe("explore:close",()=>ge(0)),Xe("quality:set",ie=>V(ie)),Xe("pointer:move",ie=>ie&&ue(ie.x,ie.y)),Xe("mode:change",ie=>B(ie&&ie.mode==="timeline"?.82:1)),Xe("timeline:scrub",ie=>{!ie||typeof ie.t!="number"||(te=(ie.t-.5)*.9,De?.kill(),F.shift=Math.max(0,Math.min(1,ie.t))*(lu-1))}),V(c);function X(){C=!0,z(),G?.kill(),he?.kill(),me?.kill(),fe?.kill(),De?.kill();for(const[ie,Q]of Pe)e.off(ie,Q);Pe.length=0,T.removeFromParent(),p.dispose(),P.dispose(),Ae.dispose(),re.dispose(),v.dispose(),g.dispose()}return{object3d:T,show:Se,update:Ve,setPointer:ue,setIntensity(ie){E=Math.max(0,Number(ie)||0)},dispose:X,get ready(){return R},get index(){return F.index},get count(){return p.drawRange.count},debug:{st:F,uniforms:w,buildMs:x,gains:_,built:m,material:P,tune:M,aura:ee,get N(){return u},setExplore:ge,setQuality:V,freezeMorph:ye,shiftTo:q}}}const tc=rs.map(({id:n,name:e})=>({id:n,name:e})),Bo=["high","mid","low"],w0={high:1.5,mid:1.25,low:1},SE=1.25,Ds={minFps:40,holdS:3,windowS:.5,settleMs:5e3,cooldownMs:4e3},ME=8e3,bE=1400,wE=6,rl=[2,2.3,2.5,1.75,1.05,1],EE=.45,TE={dental:.8},AE=/ventilator|^ct$|c-?arm|x-?ray|mri|infusion|ultrasound|defib|dialysis|anaesth|anesth/i,CE=1.25,E0={zoom:.35,centre:-.18},RE={phone:[-.114,.374],tablet:[-.13,.424],phoneAspect:.56,tabletAspect:.75},T0=6,PE=.6,ca=new URLSearchParams(window.location.search),Eh=n=>{try{return window.matchMedia(n).matches}catch{return!1}},LE=Eh("(prefers-reduced-motion: reduce)"),DE=LE?250:1900,Th=n=>new Promise(e=>setTimeout(e,n)),Io=()=>new Promise(n=>requestAnimationFrame(()=>n())),IE=n=>{const e=Number.parseInt(n,10);return Number.isFinite(e)?Math.min(wE-1,Math.max(0,e)):0};function UE(){const n=Eh("(pointer: coarse)"),e=Eh("(max-width: 768px)"),t=Math.min(window.screen?.width||1e4,window.screen?.height||1e4);return{mobile:e||n&&t<=900,memory:navigator.deviceMemory||8,cores:navigator.hardwareConcurrency||8}}function A0(n){try{let e=String(n.getParameter(n.RENDERER)||"");if(!e||/^webkit webgl$/i.test(e)){const t=n.getExtension("WEBGL_debug_renderer_info");t&&(e=String(n.getParameter(t.UNMASKED_RENDERER_WEBGL)||e))}return e}catch{return""}}function NE(n,e){const t=ca.get("quality");return Bo.includes(t)?t:/swiftshader|llvmpipe|softpipe|software|basic render/i.test(e)||n.memory<=2||n.cores<=2?"low":n.mobile||n.memory<=4||n.cores<=4||/intel/i.test(e)&&!/iris/i.test(e)?"mid":"high"}function FE(n,e){const t=new Map;return{on(i,r){if(i!=="intro:enter"||e<=0)return n.on(i,r);const s=o=>{setTimeout(()=>r(o),e)};return t.set(r,s),n.on(i,s)},off(i,r){n.off(i,t.get(r)||r),t.delete(r)},emit:(i,r)=>n.emit(i,r)}}const kl=n=>String(n??"").toLowerCase().replace(/[^a-z0-9]/g,"");function OE(n,e){const t=r=>e.findIndex(s=>kl(s.id)===kl(r));let i=t(Xh);return i<0&&(i=e.findIndex(r=>!AE.test(String(r.id)))),n.map(r=>{const s=t(r?.id);return s>=0?s:Math.max(0,i)})}function kE(n,e){const t=new Map,i=r=>r&&Number.isFinite(r.index)?{...r,index:e[r.index]??r.index}:r;return{on(r,s){if(r!=="step:change")return n.on(r,s);const o=a=>s(i(a));return t.set(s,o),n.on(r,o)},off(r,s){n.off(r,t.get(s)||s),t.delete(s)},emit:(r,s)=>n.emit(r,s),sync(r){for(const s of t.values())s({index:r,prev:r,source:"auto"})}}}const C0=typeof navigator<"u"?navigator.userActivation:void 0,_f=()=>!C0||C0.hasBeenActive;function BE(n){const e=new Map;return{on(t,i){if(t!=="intro:enter")return n.on(t,i);const r=s=>{if(_f()){i(s);return}const o=()=>{window.removeEventListener("pointerdown",o,!0),window.removeEventListener("keydown",o,!0),i(s)};window.addEventListener("pointerdown",o,!0),window.addEventListener("keydown",o,!0)};return e.set(i,r),n.on(t,r)},off(t,i){n.off(t,e.get(i)||i),e.delete(i)},emit:(t,i)=>n.emit(t,i)}}const St=L2(),nc=ca.has("debug");if(nc){const n=new Map,e=St.on.bind(St),t=St.off.bind(St),i=St.emit.bind(St),r=new Map;St.on=(s,o)=>{n.set(s,(n.get(s)||0)+1);const a=e(s,o);return()=>{n.set(s,n.get(s)-1),a()}},St.off=(s,o)=>{n.set(s,Math.max(0,(n.get(s)||0)-1)),t(s,o)},St.emit=(s,o)=>{r.set(s,(r.get(s)||0)+1),i(s,o)},St.listeners=()=>Object.fromEntries(n),St.emitted=()=>Object.fromEntries(r)}const Uo=IE(ca.get("step")),cu=UE(),Cm=Array.isArray(ih.steps)?ih.steps:[],Bl=OE(Cm,tc),zl=Cm.filter((n,e)=>kl(tc[Bl[e]]?.id)!==kl(n?.id)).map(n=>n.id),Rm=N2(ih,zl);nc&&zl.length&&console.info(`[equipseva] interim: no hologram model yet for ${zl.join(", ")}; those steps show the ${Xh} model and its interim copy`);const Pm=TM({root:document.getElementById("ui"),bus:St,content:Rm});document.getElementById("boot")?.remove();const xf=FM({bus:BE(St)}),yf={bus:St,ui:Pm,audio:xf,content:Rm,machineOfStep:Bl,machineIds:Bl.map(n=>tc[n]?.id),missingModels:zl,marks:{}},Is=n=>{yf.marks[n]=Math.round(performance.now())};nc&&(window.__es=yf);const Hl={fonts:.08,world:.3,hologram:.06,compile:.16,machines:.3,warm:.1},uu=Object.fromEntries(Object.keys(Hl).map(n=>[n,0]));let hu=0;function pi(n,e){uu[n]=Math.max(uu[n],Math.min(1,e));let t=0;for(const i in Hl)t+=Hl[i]*uu[i];(t-hu>=.01||t>=.999&&hu<.999)&&(hu=t,St.emit("load:progress",{p:Math.min(1,t)}))}const Lm=(async()=>{try{if(document.fonts?.load){const n=Promise.all([document.fonts.load('500 16px "Space Grotesk"'),document.fonts.load('400 16px "Space Grotesk"')]).then(()=>document.fonts.ready);await Promise.race([n,Th(3e3)])}}catch{}pi("fonts",1)})();let Sf=()=>{};const zE=new Promise(n=>{Sf=n});function Dm(n){console.warn("[equipseva] WebGL 2 unavailable, the HUD runs over a still backdrop",n||""),document.documentElement.classList.add("no-webgl"),St.on("intro:enter",()=>{_f()&&xf.unlock()}),Lm.then(()=>{Object.keys(Hl).forEach(e=>pi(e,1)),St.emit("load:done"),Sf()})}HE().catch(n=>{console.error("[equipseva] boot failed",n),Dm(n?.message)});async function HE(){await Io(),await Io();const n=document.getElementById("webgl"),e={alpha:!1,antialias:!1,depth:!0,stencil:!1,premultipliedAlpha:!0,preserveDrawingBuffer:!1,powerPreference:"high-performance"},t=typeof WebGL2RenderingContext<"u"?n.getContext("webgl2",e):null;if(!t){Dm();return}let i=NE(cu,A0(t));const r=B=>Math.min(window.devicePixelRatio||1,cu.mobile?Math.min(w0[B],SE):w0[B]),s=new jy({canvas:n,context:t,...e});s.toneMapping=ki,s.outputColorSpace=wt,s.setClearColor(724236,1),s.info.autoReset=!1,s.setPixelRatio(r(i)),s.setSize(window.innerWidth,window.innerHeight,!1);const o=new Zu,a=new kn(37,window.innerWidth/window.innerHeight,.2,1500);Is("renderer");const l=Fw({renderer:s,scene:o,camera:a,bus:St,quality:i});Is("world"),pi("world",1),await Io();const c=kE(FE(St,DE),Bl),u=yE({renderer:s,bus:c,quality:i});c.sync(Uo),l.hologramAnchor.add(u.object3d),Is("hologram"),pi("hologram",1);let h=null,f=1;function d(B){const{phone:q,tablet:V,phoneAspect:A,tabletAspect:E}=RE,z=Math.min(1,Math.max(0,(B-A)/(E-A)));return[q[0]+(V[0]-q[0])*z,q[1]+(V[1]-q[1])*z]}function v(B,q){const V=Math.min(1,Math.max(0,(1-B/q)/.45)),A=V*V*(3-2*V);if(f=1,A<.001){a.view?.enabled&&a.clearViewOffset();return}let E=1+E0.zoom*A,z=E0.centre*A;const $=h?.stacked&&h.w===B&&h.h===q?h:null;if($){let[ve,ue]=d(B/q);const Me=1-2*($.top+T0)/q,Re=1-2*($.bottom-T0)/q;if(Me>Re){const de=(Me-Re)/(ue-ve);if(E=Math.max(1,Math.min(E,de)),de<1){f=Math.max(PE,de);const Ve=(ve+ue)/2,Pe=(ue-ve)/2*f;ve=Ve-Pe,ue=Ve+Pe}const Ee=(ue-z)*E-Me,Ne=Re-(ve-z)*E;Ne>0?z-=Ne/E:Ee>0&&(z+=Math.min(Ee,-Ne)/E)}}const ne=B*E,te=q*E;a.setViewOffset(ne,te,(ne-B)/2,te/2*(1-z)-q/2,B,q)}let g=!1,p=!1;function m(){const B=Math.max(1,window.innerWidth),q=Math.max(1,window.innerHeight);s.setPixelRatio(r(i)),s.setSize(B,q,!1),l.resize(B,q),v(B,q),p=!0}m();let x=!1;const _=()=>{x||(x=!0,requestAnimationFrame(()=>{x=!1,m()}))};window.addEventListener("resize",_),window.visualViewport?.addEventListener("resize",_),St.on("hud:frame",B=>{h=B||null,v(Math.max(1,window.innerWidth),Math.max(1,window.innerHeight)),p=!0}),St.emit("quality:set",{tier:i}),Uo>0&&(St.emit("step:change",{index:Uo,prev:0,source:"auto"}),l.setStep(Uo,{duration:0}));let y=null;window.addEventListener("pointermove",B=>{B.pointerType!=="touch"&&(y={x:B.clientX/window.innerWidth*2-1,y:-(B.clientY/window.innerHeight*2-1)})},{passive:!0}),document.addEventListener("mouseout",B=>{B.relatedTarget||(y={x:0,y:0})}),window.addEventListener("blur",()=>{y={x:0,y:0}});const C=Bo.includes(ca.get("quality")),M={armedAt:1/0,win:[],winT:0,bad:0,steps:[]};function w(B,q){B===i||!Bo.includes(B)||(i=B,s.setPixelRatio(r(i)),St.emit("quality:set",{tier:i}),m(),M.steps.push({tier:i,why:q,at:Math.round(performance.now())}),nc&&console.info(`[equipseva] quality -> ${i} (${q})`))}function P(B,q){const V=()=>{M.win.length=0,M.winT=0};if(C||q<M.armedAt||document.hidden||i==="low"||B>.5){V();return}if(M.win.push(B),M.winT+=B,M.winT<Ds.windowS)return;M.win.sort((E,z)=>E-z);const A=1/Math.max(.001,M.win[M.win.length>>1]);V(),M.bad=A<Ds.minFps?M.bad+Ds.windowS:0,M.bad>=Ds.holdS&&(M.bad=0,M.armedAt=q+Ds.cooldownMs,w(Bo[Bo.indexOf(i)+1],`${A.toFixed(0)} fps`))}const I=new Float32Array(240);let S=0,b=0,N=!1,R=0,H=0,T=0,k=0,Z=!1,K=!1,pe=0,ce=0,W=0,re={calls:0,triangles:0,points:0};const Ae=l.state;function ee(){const B=rl.length,q=((Number(Ae?.mood)||0)%B+B)%B,V=Math.floor(q),A=q-V,E=rl[V]+(rl[(V+1)%B]-rl[V])*A,z=Math.min(1,Math.max(0,(Number(Ae?.dim)||0)/.85)),$=1+(E-1)*EE;return E+($-E)*z}let F=1;function xe(B){const q=Math.min(1,Math.max(0,Number(Ae?.explore)||0)),V=tc[u.index>=0?u.index:0]?.id,A=(1+((TE[V]??1)-1)*q)*f;F+=(A-F)*(1-Math.exp(-B*5)),u.object3d.scale.setScalar(F),u.object3d.position.y=(1-F)*CE}function G(B){s.info.reset(),l.update(B,H),u.setIntensity(ee()),xe(B),u.update(B,H),l.render(),k++,re={calls:s.info.render.calls,triangles:s.info.render.triangles,points:s.info.render.points}}function he(B){b=requestAnimationFrame(he);const q=R?(B-R)/1e3:1/60;if(R=B,g&&!p)return;p=!1;const V=Math.min(Math.max(q,0),.1);if(H+=V,T++,y&&(St.emit("pointer:move",y),y=null),!(!Z&&T%4!==0)){try{G(V)}catch(A){K=!0,fe(),console.error("[equipseva] frame failed, render loop stopped",A);return}I[S++%I.length]=q,ce+=q,W++,ce>=.5&&(pe=W/ce,ce=0,W=0),P(q,B)}}function me(){N||K||document.hidden||(N=!0,R=0,p=!0,b=requestAnimationFrame(he))}function fe(){N=!1,cancelAnimationFrame(b)}document.addEventListener("visibilitychange",()=>{document.hidden?fe():me()}),n.addEventListener("webglcontextlost",B=>{B.preventDefault(),fe()}),n.addEventListener("webglcontextrestored",()=>{m(),me()}),Object.assign(yf,{world:l,hologram:u,renderer:s,scene:o,camera:a,loaded:zE,setTier:w,tier:()=>i,stats(){const B=Math.min(S,I.length),q=Array.from(I.slice(0,B)).sort((E,z)=>E-z),V=q[Math.floor(B/2)]||0,A=q[Math.floor(B*.95)]||0;return{fps:Math.round(pe),medianMs:+(V*1e3).toFixed(2),p95Ms:+(A*1e3).toFixed(2),calls:re.calls,triangles:re.triangles,points:re.points,tier:i,dpr:s.getPixelRatio(),buffer:[s.domElement.width,s.domElement.height],watchdog:M.steps,programs:s.info.programs?.length,gpu:A0(t),device:cu,loaded:Z,frames:k,running:N,view:a.view?.enabled?[+a.view.fullWidth.toFixed(1),+a.view.offsetY.toFixed(1)]:null}}}),St.on("intro:enter",()=>{_f()&&xf.unlock(),M.armedAt=performance.now()+Ds.settleMs});let De=0;St.on("menu:open",()=>{clearTimeout(De),De=setTimeout(()=>{g=!0},bE)}),St.on("menu:close",()=>{clearTimeout(De),g=!1});try{s.compileAsync?await Promise.race([s.compileAsync(o,a),Th(5e3)]):s.compile(o,a)}catch{}pi("compile",.6),await Io(),G(1/60);const se=l.state;if(se&&typeof se.dim=="number"){const B=se.dim;se.dim=.01,G(1/60),se.dim=B}G(1/60),Is("compiled"),pi("compile",1),me();const U=u.debug?.built,Se=performance.now();let ye=!1;await Promise.race([Promise.resolve(u.ready).then(()=>{ye=!0}),(async()=>{for(;!ye&&performance.now()-Se<ME;)U&&pi("machines",U.filter(Boolean).length/U.length),await Th(100)})()]),ye=!0,Is("machines"),pi("machines",1),await Lm,Z=!0;const ge=k;for(;k-ge<4&&!K&&!document.hidden;)await Io(),pi("warm",(k-ge)/4);pi("warm",1),Is("loadDone"),St.emit("load:done"),Sf(),ca.has("skipintro")&&Pm.jumpHome({step:Uo})}
