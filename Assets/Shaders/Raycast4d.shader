Shader "Custom/Raycast4d"
{
	Properties
	{
		//_MainTex ("Texture", 2D) = "white" {}
		fogDist ("Fog distane", Float) = 50.0
		fogColor("Fog Color", Color) = (0, 0, 0, 0)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
CGPROGRAM
#pragma vertex vert
#pragma fragment frag

// make fog work
#pragma multi_compile_fog
#pragma target 5.0			
#include "UnityCG.cginc"

struct Sphere{
	float4 pos;
	float radius;
	float3 color;
};

Sphere makeSphere(in float4 pos, in float radius, in float3 color){
	Sphere result;
	result.pos = pos;
	result.radius = radius;
	result.color = color;
	return result;
}

///////
    
struct Plane{
	float4 pos;
	float4 n;
};

Plane makePlane(in float4 pos, in float4 n){
	Plane result;
	result.pos = pos;
	result.n = n;
	return result;
}

///////
    
struct RayHit{
	float3 color;
	float4 n;
	float dist;
};
    
RayHit makeRayHit(float3 col, float4 n, float dist){
	RayHit result;
	result.color = col;
	result.n =  n;
	result.dist = dist;
	return result;
}
/////

struct Viewer{
	float4 pos;
	float4 right;
	float4 up;
	float4 forward;
};

Viewer createViewer(in float4 pos, in float4 right, in float4 up, in float4 forward){
	Viewer result;
	result.pos = pos;
	result.right = right;
	result.up = up;
	result.forward = forward;
	return result;
}
    
/////
struct Ray{
	float4 start;
	float4 dir;
};

Ray makeRay(in float4 start, in float4 dir){
	Ray result;
	result.start = start;
	result.dir = dir;
	return result;
}

#define maxDistance 100000.0
//float maxDistance = 100000.0;
float fogDist = 50.0;
float4 fogColor = float4(0.0, 0.0, 0.0, 1.0);//float3(0.0, 0.0, 0.0);
#define pi 3.14159265359
//const float pi = 3.14159265359;
#define zero4 float4(0.0, 0.0, 0.0, 0.0)
//const float4 zero4 = float4(0.0, 0.0, 0.0, 0.0);
    
float3 applyFog(in float3 col, float dist){
    float fogBlend = clamp(dist/fogDist, 0.0, 1.0);
    return lerp(col, fogColor.xyz, fogBlend);    
}

RayHit mixRayHits(in RayHit a, in RayHit b, float factor){
	return makeRayHit(
		lerp(a.color, b.color, factor),
		lerp(a.n, b.n, factor),
		lerp(a.dist, b.dist, factor)
	);
}

RayHit selectClosest(in RayHit a, in RayHit b){
    float mixFactor = float(b.dist < a.dist);
    RayHit result = makeRayHit(
        lerp(a.color, b.color, mixFactor),
        lerp(a.n, b.n, mixFactor),
        min(a.dist, b.dist)
    );
    return result;
}

float3 sceneColor(in float4 p){
    float3 color = float3(1.0, 1.0, 1.0);
    float3 colorPos = frac(p.xyz);// - float3(0.5, 0.5, 0.5));
    color.xyz = step(0.5, colorPos);
    return color;
}

RayHit rayVsPlane(in Ray ray, in Plane plane){
    RayHit result = makeRayHit(float3(0.0, 0.0, 0.0), -ray.dir, maxDistance);
    RayHit defaultResult = result;
    
    float planeDot = dot(ray.dir, -plane.n);
    float normalDist = dot(ray.start - plane.pos, plane.n);
    float t = normalDist / planeDot;
    result.dist = t;
    result.n = plane.n;
    result.color = sceneColor(ray.start + ray.dir * t);//float3(1.0, 1.0, 1.0);
    //return result;
    return mixRayHits(defaultResult, result, float(
        (planeDot > 0.0) && (t > 0.0)
    ));
	    
    
    return result;
}

RayHit rayVsSphere(in Ray ray, in Sphere sphere){
    RayHit defaultResult = makeRayHit(fogColor.xyz, -ray.dir, maxDistance);
    
    //pythogorean solution
    float4 sphereDiff = sphere.pos - ray.start;
    float sphereDist = dot(sphereDiff, ray.dir);
    float spherePerpDist = sqrt(dot(sphereDiff, sphereDiff) - sphereDist * sphereDist);
    
    float dt2 = sphere.radius * sphere.radius - spherePerpDist * spherePerpDist;
    float dt = sqrt(dt2);
    
    float t = sphereDist - dt;//no need for t2, as we haven no refractions
    float4 hitPos = ray.start + ray.dir * t;
    float4 sphereNormal = clamp(normalize(hitPos - sphere.pos), -1.0, 1.0);
    RayHit sphereHit = makeRayHit(
        sphere.color,
        sphereNormal,
        t
    );
    
    return mixRayHits(
        defaultResult, sphereHit, float((spherePerpDist < sphere.radius) && (t > 0.0))
    );
}

/*
Ray makeRay(in float2 fragCoord, in Viewer viewer){
    float2 uv = fragCoord/iResolution.xy;    
    uv = uv * 2.0 - 1.0;
    uv.y *= iResolution.y/iResolution.x;
    Ray result = Ray(
        viewer.pos,
        viewer.forward + viewer.right * uv.x + viewer.up * uv.y
    );
    result.dir = normalize(result.dir);
    return result;
}
*/

#define numMovingSpheres 3
//const int numMovingSpheres = 3;

struct Orbit{
    float period;
    float radius;
    float4 origin;
    float4 xVec;
    float4 yVec;
};

Orbit makeOrbit(in float period, in float radius, in float4 origin, in float4 xVec, in float4 yVec){
	Orbit result;
	result.period = period;
	result.radius = radius;
	result.origin = origin;
	result.xVec = xVec;
	result.yVec= yVec;
	return result;
}
    
struct SphereConfig{
    Orbit orbit;
    float3 color;
    float radius;
};

SphereConfig makeSphereConfig(in Orbit orbit, in float3 color, in float radius){
	SphereConfig result;
	result.orbit = orbit;
	result.color = color;
	result.radius = radius;
	return result;
}

struct SceneConfig{
    Orbit sunOrbit;
    SphereConfig spheres[numMovingSpheres];
};
    
float getTime(){
	return _Time.y;
}
    
float4 getOrbitPos(in Orbit orbit){    
    float angle = frac(getTime()/orbit.period) * pi * 2.0;
    
    return orbit.origin 
        + cos(angle) * orbit.radius * orbit.xVec 
        + sin(angle) * orbit.radius * orbit.yVec;        
}

struct Scene{
    float4 sunPos;
    Plane plane;
    Sphere mainSphere;
    Sphere spheres[numMovingSpheres];
};

Scene makeScene(in SceneConfig sceneConfig){
    Scene scene;
    scene.plane = makePlane(float4(0.0, -1.7, 0.0, 0.0), float4(0.0, 1.0, 0.0, 0.0));
    scene.mainSphere = makeSphere(float4(0.0, 0.0, 0.0, 0.0), 0.5, float3(1.0, 1.0, 1.0)); 
    
    for(int i = 0; i < numMovingSpheres; i++){
        float4 pos = getOrbitPos(sceneConfig.spheres[i].orbit);
        scene.spheres[i].pos = pos;
        scene.spheres[i].color = sceneConfig.spheres[i].color;
        scene.spheres[i].radius = sceneConfig.spheres[i].radius;
    }
    scene.sunPos = getOrbitPos(sceneConfig.sunOrbit);
    return scene;
}

RayHit rayCastBase(in Ray ray, in Scene scene){
    RayHit result = makeRayHit(fogColor.xyz, -ray.dir, maxDistance);
    result = selectClosest(result, rayVsPlane(ray, scene.plane));
    //return result;
    result = selectClosest(result, rayVsSphere(ray, scene.mainSphere));
    for(int i = 0; i < numMovingSpheres; i++){
    	result = selectClosest(result, rayVsSphere(ray, scene.spheres[i]));
    }
    return result;
}

float getLightFactor(in float4 lightPos, in float4 worldPos, in float4 worldNormal, in Scene scene){
    float4 diff = lightPos - worldPos;
    float lightDist = length(diff);
    float4 lightDir = normalize(diff);
    float lightDot = clamp(dot(lightDir, worldNormal), 0.0, 1.0);
    
    //shadow
    Ray lightRay = makeRay(scene.sunPos, -lightDir);
    RayHit lightHit = rayCastBase(lightRay, scene);    
    
    const float shadowBias = 0.01;
    
    return lightDot * float((lightHit.dist + shadowBias) > lightDist);
}

float3 rayCastScene(in Ray originalRay, in Scene scene){
    const float3 ambientColor = float3(0.2, 0.2, 0.2);
    float3 finalColor = 0.0;
    
    Ray curRay = originalRay;
    float baseFogDist = 0.0;
  	float subRayMultiplier = 1.0;
    
	//const int maxSurfaceHits = 4;
    //for (int i = 0; i < maxSurfaceHits; i++){    
    for (int i = 0; i < 4; i++){    
    	RayHit curHit = rayCastBase(curRay, scene);

    	float rayDot = clamp(dot(-curRay.dir, curHit.n), 0.0, 1.0);
   		float fresnSimple = 1.0 - rayDot;
    	fresnSimple = lerp(0.25, 1.0, fresnSimple * fresnSimple);
    
    	float3 baseColor = curHit.color;
    	float4 worldPos = curHit.dist * curRay.dir + curRay.start;
    	float4 worldNormal = curHit.n;
    
    	float lightFactor = getLightFactor(scene.sunPos, worldPos, worldNormal, scene);
        
        float3 curFinalColor = 0.0;//float3(0.0);
        curFinalColor += baseColor * ambientColor;
        curFinalColor += baseColor * lightFactor;
        curFinalColor = applyFog(curFinalColor, curHit.dist + baseFogDist);
            
        finalColor = lerp(finalColor, curFinalColor, subRayMultiplier);
        
    	const float bounceBias = 0.001;
    	float4 reflected = reflect(curRay.dir, curHit.n);
    	float4 curPos = curRay.start + curRay.dir * curHit.dist;
    	Ray nextRay = makeRay(curPos + reflected * bounceBias, reflected);            
        baseFogDist += curHit.dist + bounceBias;
        
        subRayMultiplier *= fresnSimple;
        curRay = nextRay;
    }
    
    return finalColor;
}

float4 planeProjectNormalize(in float4 v, in float4 n){
    return normalize(v - n *dot(v, n));
}

float4 getCurViewerPosition(){
    const float timePeriod = 30.0;
    
	#define numPositions 8
    //const int numPositions = 7;
    float4 positions[numPositions] = {
        float4(-3.0, 1.0, -3.0, 0.0),
        float4(3.0, 1.0, -3.0, 0.0),
        float4(3.0, 1.0, -3.0, -3.0),
        float4(3.0, 1.0, 0.0, -3.0),
        float4(0.0, 1.0, 0.0, -3.0),
        float4(0.0, 0.0, 0.0, -3.0),
        float4(1.0, 1.0, 1.0, 6.0),
        float4(-3.0, 1.0, -3.0, 0.0)
    };
    
    float lerpScale = 4.0;
    
    float fracPeriod = frac(getTime()/timePeriod);
    float curPosFloat = fracPeriod * float(numPositions);
    int curPos = int(floor(curPosFloat)) % numPositions;
    float curLerp = frac(curPosFloat);
    curLerp = clamp(curLerp * lerpScale, 0.0, 1.0);
    int nextPos = (curPos + 1) % numPositions;
    return lerp(positions[curPos], positions[nextPos], curLerp);    
    #undef numPositions
}

Viewer makeViewer(){
    float4 target = float4(0.0, 0.0, 0.0, 0.0);
    
    Viewer result = createViewer(
        float4(0.0, 0.0, -3.0, 0.0),
        float4(1.0, 0.0, 0.0, 0.0),
        float4(0.0, 1.0, 0.0, 0.0),
        float4(0.0, 0.0, 1.0, 0.0)
    );
    
	result.pos = getCurViewerPosition();
    result.forward = normalize(target - result.pos);
    result.up = planeProjectNormalize(result.up, result.forward);
    result.right = planeProjectNormalize(result.right, result.forward);
    result.right = planeProjectNormalize(result.right, result.up);
    
    return result;    
}

SceneConfig makeSceneConfig(){
	SceneConfig result;
	/*
    Orbit sunOrbit;
    SphereConfig spheres[numMovingSpheres];

	*/
	result.sunOrbit = makeOrbit(15.0, 1.0, float4(0.0, 5.0, 0.0, 0.0), float4(1.0, 0.0, 0.0, 0.0), float4(0.0, 0.0, 1.0, 0.0));
	result.spheres[0] = makeSphereConfig(
		makeOrbit(3.0, 1.0, zero4, float4(1.0, 0.0, 0.0, 0.0), float4(0.0, 0.0, 1.0, 0.0)), 
			float3(0.25, 1.0, 0.25), 0.25);
	result.spheres[1] = makeSphereConfig(
		makeOrbit(5.0, 1.5, zero4, float4(1.0, 0.0, 0.0, 0.0), float4(0.0, 1.0, 0.0, 0.0)), 
			float3(0.25, 0.25, 1.0), 0.25);
	result.spheres[2] = makeSphereConfig(
		makeOrbit(7.0, 2.0, zero4, float4(1.0, 0.0, 0.0, 0.0), float4(0.0, 0.0, 0.0, 1.0)), 
			float3(1.0, 0.25, 0.25), 0.5);
	return result;
}

/*
void mainImage( out float4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    //vec2 uv = fragCoord/iResolution.xy;
    Scene scene = makeScene(sceneConfig);
    Viewer viewer = makeViewer();
        
    Ray ray = makeRay(fragCoord, viewer);

    float3 col = rayCastScene(ray, scene);
    
    // Output to screen
    fragColor = float4(col,1.0);
}*/

struct appdata{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
};

struct v2f{
	float2 uv : TEXCOORD0;
	float3 worldPos: TEXCOORD1;
	UNITY_FOG_COORDS(2)
	float4 vertex : SV_POSITION;
};

//sampler2D _MainTex;
//float4 _MainTex_ST;
			
v2f vert (appdata v)
{
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;//UnityObjectToWorld(v.vertex);
	o.uv = v.uv;//TRANSFORM_TEX(v.uv, _MainTex);
	UNITY_TRANSFER_FOG(o,o.vertex);
	return o;
}

float3 getRayToCamera(float3 worldPos){
	if (unity_OrthoParams.w > 0){
		return -UNITY_MATRIX_V[2].xyz;;
	}
	else
		return worldPos  - _WorldSpaceCameraPos;
}

float4 vecTo4d(in float4 pt, in Viewer viewer){
	return viewer.forward * pt.z
		+ viewer.right * pt.x
		+ viewer.up * pt.y
		+ viewer.pos * pt.w;		
}
			
fixed4 frag (v2f i) : SV_Target{
	// sample the texture
	//fixed4 col = tex2D(_MainTex, i.uv);
	
	float3 worldPos = i.worldPos;
	float3 rayDir = normalize(getRayToCamera(worldPos));
	
	//return float4(worldPos/10.0, 1.0);
	//return float4(rayDir, 1.0);

	SceneConfig sceneConfig = makeSceneConfig();	
    Scene scene = makeScene(sceneConfig);
    Viewer viewer = makeViewer();
        
    Ray ray = makeRay(
		vecTo4d(float4(worldPos, 1.0), viewer), 
		vecTo4d(float4(rayDir, 0.0), viewer)
	);

    float3 sceneColor = rayCastScene(ray, scene);	
	
	fixed4 col = float4(worldPos, 1.0);
	float3 tmp = viewer.forward.xyz;
	col.xyz = rayDir;//float4(ray.start.xyz, 1.0);
	col.xyz = sceneColor;
	//col.xyz = pi;
	// apply fog
	UNITY_APPLY_FOG(i.fogCoord, col);
	return col;
}
ENDCG
		}
	}
}
