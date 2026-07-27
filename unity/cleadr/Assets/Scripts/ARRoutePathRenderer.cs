using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Unity.XR.CoreUtils;
using UnityEngine;

/// <summary>
/// Renders a continuous 3D blue line on the road surface in AR space to visually
/// trace the navigation route path. The line has height and depth with proper
/// lighting to match the 3D turn direction arrows.
/// </summary>
public class ARRoutePathRenderer : MonoBehaviour
{
    [Header("References")]
    public XROrigin XROrigin;

    [Header("Line Dimensions")]
    [Tooltip("Width of the route path line in meters")]
    public float lineWidth = 0.6f;

    [Tooltip("Height/thickness of the 3D line in meters")]
    public float lineHeight = 0.08f;

    [Tooltip("Y offset below the camera to simulate road surface placement")]
    public float roadSurfaceYOffset = -1.5f;

    [Header("Rendering Range")]
    [Tooltip("Maximum distance (meters) ahead of the user to render path points")]
    public float maxRenderDistance = 150f;

    [Tooltip("Minimum distance (meters) between rendered points to avoid clutter")]
    public float minPointSpacing = 1.5f;

    [Tooltip("Distance (meters) ahead of camera where the line starts")]
    public float lineStartOffset = 1.5f;

    [Header("Colors")]
    [Tooltip("Main 3D line color")]
    public Color lineColor = new Color(0.0f, 0.5f, 1.0f, 0.92f);

    [Tooltip("Glow/outer flat color")]
    public Color glowColor = new Color(0.0f, 0.35f, 1.0f, 0.25f);

    [Tooltip("Emission color intensity for the 3D glow effect")]
    public float emissionIntensity = 0.4f;

    // Route data from Flutter
    private List<RouteCoordinate> routeCoordinates = new List<RouteCoordinate>();
    private double deviceLatitude;
    private double deviceLongitude;
    private bool hasDeviceLocation = false;
    private bool hasRouteData = false;

    // 3D line mesh
    private GameObject lineObject;
    private MeshFilter lineMeshFilter;
    private MeshRenderer lineMeshRenderer;
    private Mesh lineMesh;
    private Material lineMaterial;

    // Flat glow mesh (underneath the 3D line)
    private GameObject glowObject;
    private MeshFilter glowMeshFilter;
    private MeshRenderer glowMeshRenderer;
    private Mesh glowMesh;
    private Material glowMaterial;

    // Animation
    private float pulseTimer = 0f;
    private float pulseSpeed = 1.5f;
    private float minAlpha = 0.8f;
    private float maxAlpha = 1.0f;

    void Awake()
    {
        CreateMeshObjects();
    }

    void Update()
    {
        if (!hasRouteData || !hasDeviceLocation || XROrigin == null) return;

        UpdateMeshes();
        AnimatePulse();
    }

    /// <summary>
    /// Called from Flutter via Unity message to update the route path coordinates.
    /// Expects JSON: { "coordinates": [{"lat": 0.0, "lng": 0.0}, ...] }
    /// </summary>
    public void UpdateRoutePath(string jsonMessage)
    {
        try
        {
            var routeMessage = JsonConvert.DeserializeObject<RoutePathMessage>(jsonMessage);
            if (routeMessage?.coordinates != null && routeMessage.coordinates.Count > 0)
            {
                routeCoordinates = routeMessage.coordinates;
                hasRouteData = true;
                Debug.Log($"[ARRoutePathRenderer] Received {routeCoordinates.Count} route coordinates");
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"[ARRoutePathRenderer] Failed to parse route path: {e.Message}");
        }
    }

    /// <summary>
    /// Called from Flutter via Unity message to update the device's current GPS location.
    /// Expects JSON: { "lat": 0.0, "lng": 0.0 }
    /// </summary>
    public void UpdateDeviceLocation(string jsonMessage)
    {
        try
        {
            var locMessage = JsonConvert.DeserializeObject<RouteCoordinate>(jsonMessage);
            if (locMessage != null)
            {
                deviceLatitude = locMessage.lat;
                deviceLongitude = locMessage.lng;
                hasDeviceLocation = true;
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"[ARRoutePathRenderer] Failed to parse device location: {e.Message}");
        }
    }

    private void CreateMeshObjects()
    {
        // --- 3D Line (Lit material for realistic lighting like the 3D arrows) ---
        Shader litShader = FindShader("Universal Render Pipeline/Lit");
        lineMaterial = new Material(litShader);
        SetMaterialTransparent(lineMaterial, lineColor);

        // Add emission for a subtle self-illumination glow
        lineMaterial.EnableKeyword("_EMISSION");
        if (lineMaterial.HasProperty("_EmissionColor"))
        {
            Color emColor = lineColor * emissionIntensity;
            lineMaterial.SetColor("_EmissionColor", emColor);
        }
        // Smoothness for a polished surface like the 3D arrows
        if (lineMaterial.HasProperty("_Smoothness"))
            lineMaterial.SetFloat("_Smoothness", 0.7f);
        if (lineMaterial.HasProperty("_Metallic"))
            lineMaterial.SetFloat("_Metallic", 0.15f);

        lineObject = new GameObject("RoutePathLine3D");
        lineObject.transform.SetParent(transform);
        lineMeshFilter = lineObject.AddComponent<MeshFilter>();
        lineMeshRenderer = lineObject.AddComponent<MeshRenderer>();
        lineMesh = new Mesh { name = "RoutePathLine3DMesh" };
        lineMeshFilter.mesh = lineMesh;
        lineMeshRenderer.material = lineMaterial;
        lineMeshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
        lineMeshRenderer.receiveShadows = true;

        // --- Flat Glow (Unlit, underneath the 3D line) ---
        Shader unlitShader = FindShader("Universal Render Pipeline/Unlit");
        glowMaterial = new Material(unlitShader);
        SetMaterialTransparent(glowMaterial, glowColor);

        glowObject = new GameObject("RoutePathGlow");
        glowObject.transform.SetParent(transform);
        glowMeshFilter = glowObject.AddComponent<MeshFilter>();
        glowMeshRenderer = glowObject.AddComponent<MeshRenderer>();
        glowMesh = new Mesh { name = "RoutePathGlowMesh" };
        glowMeshFilter.mesh = glowMesh;
        glowMeshRenderer.material = glowMaterial;
        glowMeshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        glowMeshRenderer.receiveShadows = false;
    }

    private Shader FindShader(string preferred)
    {
        Shader shader = Shader.Find(preferred);
        if (shader != null) return shader;

        shader = Shader.Find("Universal Render Pipeline/Lit");
        if (shader != null) return shader;

        shader = Shader.Find("Universal Render Pipeline/Unlit");
        if (shader != null) return shader;

        shader = Shader.Find("Unlit/Color");
        if (shader != null) return shader;

        Debug.LogError($"[ARRoutePathRenderer] No suitable shader found for '{preferred}'");
        return Shader.Find("Hidden/InternalErrorShader");
    }

    private void SetMaterialTransparent(Material mat, Color color)
    {
        mat.color = color;

        // URP transparency settings
        if (mat.HasProperty("_Surface"))
        {
            mat.SetFloat("_Surface", 1); // 1 = Transparent
            mat.SetFloat("_Blend", 0);   // 0 = Alpha blend
        }
        if (mat.HasProperty("_SrcBlend"))
            mat.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
        if (mat.HasProperty("_DstBlend"))
            mat.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        if (mat.HasProperty("_ZWrite"))
            mat.SetFloat("_ZWrite", 0);

        mat.renderQueue = 3000;
        mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
        mat.EnableKeyword("_ALPHABLEND_ON");
        mat.DisableKeyword("_ALPHATEST_ON");
    }

    /// <summary>
    /// Updates both the 3D line mesh and the flat glow mesh.
    /// </summary>
    private void UpdateMeshes()
    {
        Camera cam = XROrigin.Camera;
        if (cam == null) return;

        List<Vector3> linePoints = GetFilteredRoutePoints(cam);

        // Build 3D extruded ribbon for the main line
        Build3DRibbonMesh(lineMesh, linePoints, lineWidth, lineHeight);

        // Build flat quad-strip for the glow underneath
        BuildFlatQuadStripMesh(glowMesh, linePoints, lineWidth * 2.5f);
    }

    /// <summary>
    /// Filters GPS route coordinates to AR positions within view range.
    /// </summary>
    private List<Vector3> GetFilteredRoutePoints(Camera cam)
    {
        Vector3 camPos = cam.transform.position;
        Vector3 camForward = cam.transform.forward;
        Vector3 camForwardH = new Vector3(camForward.x, 0, camForward.z).normalized;
        float roadY = camPos.y + roadSurfaceYOffset;

        List<Vector3> points = new List<Vector3>();

        for (int i = 0; i < routeCoordinates.Count; i++)
        {
            var coord = routeCoordinates[i];
            Vector3 localPos = GpsToLocalPosition(coord.lat, coord.lng, camPos);
            localPos.y = roadY;

            Vector3 toCandidate = localPos - camPos;
            toCandidate.y = 0;
            float distance = toCandidate.magnitude;

            if (distance > maxRenderDistance) continue;

            float dotForward = Vector3.Dot(toCandidate.normalized, camForwardH);
            if (dotForward < -0.1f && distance > 5f) continue;

            if (points.Count > 0)
            {
                float spacing = Vector3.Distance(points[points.Count - 1], localPos);
                if (spacing < minPointSpacing) continue;
            }

            points.Add(localPos);
        }

        // Insert start point near camera
        if (points.Count > 1)
        {
            Vector3 startPoint = camPos + camForwardH * lineStartOffset;
            startPoint.y = roadY;
            points.Insert(0, startPoint);
        }

        return points;
    }

    /// <summary>
    /// Builds a 3D extruded ribbon mesh with top face, left side, and right side.
    /// Cross-section is a flat box: the line has width and height, giving it
    /// a solid 3D appearance similar to the 3D turn direction arrows.
    /// </summary>
    private void Build3DRibbonMesh(Mesh mesh, List<Vector3> points, float width, float height)
    {
        mesh.Clear();
        if (points.Count < 2) return;

        int n = points.Count;
        // 8 vertices per point: 4 for top face, 4 for sides (shared differently for normals)
        // Simplified: 4 unique positions per point, but we duplicate for normal directions
        // Top face: 2 verts (top-left, top-right) with up normals
        // Left side: 2 verts (bottom-left, top-left) with left normals
        // Right side: 2 verts (bottom-right, top-right) with right normals
        // Total: 6 verts per point (for 3 faces)

        int vertsPerPoint = 6;
        int totalVerts = n * vertsPerPoint;

        Vector3[] vertices = new Vector3[totalVerts];
        Vector3[] normals = new Vector3[totalVerts];
        Color[] colors = new Color[totalVerts];

        // Triangles: per segment (n-1 segments)
        // Top face: 2 triangles = 6 indices
        // Left side: 2 triangles = 6 indices
        // Right side: 2 triangles = 6 indices
        // Total: 18 indices per segment
        int[] triangles = new int[(n - 1) * 18];

        float halfWidth = width / 2f;

        for (int i = 0; i < n; i++)
        {
            // Direction along the path
            Vector3 forward;
            if (i == 0)
                forward = (points[1] - points[0]).normalized;
            else if (i == n - 1)
                forward = (points[i] - points[i - 1]).normalized;
            else
                forward = ((points[i + 1] - points[i]).normalized + (points[i] - points[i - 1]).normalized).normalized;

            // Perpendicular on horizontal plane
            Vector3 right = Vector3.Cross(Vector3.up, forward).normalized;

            // 4 corner positions of the cross-section
            Vector3 bottomLeft  = points[i] - right * halfWidth;
            Vector3 bottomRight = points[i] + right * halfWidth;
            Vector3 topLeft     = bottomLeft  + Vector3.up * height;
            Vector3 topRight    = bottomRight + Vector3.up * height;

            // Alpha fade at the far end
            float t = (float)i / (n - 1);
            float alpha = t < 0.75f ? 1.0f : 1.0f - ((t - 0.75f) / 0.25f);
            Color vertColor = new Color(1, 1, 1, alpha);

            int baseIdx = i * vertsPerPoint;

            // Top face verts (indices 0, 1) — normal pointing up
            vertices[baseIdx + 0] = topLeft;
            vertices[baseIdx + 1] = topRight;
            normals[baseIdx + 0]  = Vector3.up;
            normals[baseIdx + 1]  = Vector3.up;
            colors[baseIdx + 0]   = vertColor;
            colors[baseIdx + 1]   = vertColor;

            // Left side verts (indices 2, 3) — normal pointing left
            vertices[baseIdx + 2] = bottomLeft;
            vertices[baseIdx + 3] = topLeft;
            normals[baseIdx + 2]  = -right;
            normals[baseIdx + 3]  = -right;
            colors[baseIdx + 2]   = vertColor;
            colors[baseIdx + 3]   = vertColor;

            // Right side verts (indices 4, 5) — normal pointing right
            vertices[baseIdx + 4] = topRight;
            vertices[baseIdx + 5] = bottomRight;
            normals[baseIdx + 4]  = right;
            normals[baseIdx + 5]  = right;
            colors[baseIdx + 4]   = vertColor;
            colors[baseIdx + 5]   = vertColor;
        }

        // Build triangles for each segment
        int triIdx = 0;
        for (int i = 0; i < n - 1; i++)
        {
            int curr = i * vertsPerPoint;
            int next = (i + 1) * vertsPerPoint;

            // --- Top face ---
            // curr+0=topLeft_curr, curr+1=topRight_curr
            // next+0=topLeft_next, next+1=topRight_next
            triangles[triIdx++] = curr + 0; // topLeft_curr
            triangles[triIdx++] = next + 0; // topLeft_next
            triangles[triIdx++] = curr + 1; // topRight_curr

            triangles[triIdx++] = curr + 1; // topRight_curr
            triangles[triIdx++] = next + 0; // topLeft_next
            triangles[triIdx++] = next + 1; // topRight_next

            // --- Left side ---
            // curr+2=bottomLeft_curr, curr+3=topLeft_curr
            // next+2=bottomLeft_next, next+3=topLeft_next
            triangles[triIdx++] = curr + 2; // bottomLeft_curr
            triangles[triIdx++] = next + 2; // bottomLeft_next
            triangles[triIdx++] = curr + 3; // topLeft_curr

            triangles[triIdx++] = curr + 3; // topLeft_curr
            triangles[triIdx++] = next + 2; // bottomLeft_next
            triangles[triIdx++] = next + 3; // topLeft_next

            // --- Right side ---
            // curr+4=topRight_curr, curr+5=bottomRight_curr
            // next+4=topRight_next, next+5=bottomRight_next
            triangles[triIdx++] = curr + 4; // topRight_curr
            triangles[triIdx++] = next + 4; // topRight_next
            triangles[triIdx++] = curr + 5; // bottomRight_curr

            triangles[triIdx++] = curr + 5; // bottomRight_curr
            triangles[triIdx++] = next + 4; // topRight_next
            triangles[triIdx++] = next + 5; // bottomRight_next
        }

        mesh.vertices = vertices;
        mesh.normals = normals;
        mesh.triangles = triangles;
        mesh.colors = colors;
        mesh.RecalculateBounds();
    }

    /// <summary>
    /// Builds a flat quad-strip for the glow effect underneath the 3D line.
    /// </summary>
    private void BuildFlatQuadStripMesh(Mesh mesh, List<Vector3> points, float width)
    {
        mesh.Clear();
        if (points.Count < 2) return;

        int n = points.Count;
        Vector3[] vertices = new Vector3[n * 2];
        int[] triangles = new int[(n - 1) * 6];
        Color[] colors = new Color[n * 2];
        float halfWidth = width / 2f;

        for (int i = 0; i < n; i++)
        {
            Vector3 forward;
            if (i == 0)
                forward = (points[1] - points[0]).normalized;
            else if (i == n - 1)
                forward = (points[i] - points[i - 1]).normalized;
            else
                forward = ((points[i + 1] - points[i]).normalized + (points[i] - points[i - 1]).normalized).normalized;

            Vector3 right = Vector3.Cross(Vector3.up, forward).normalized * halfWidth;

            // Slight Y offset below the 3D line so glow is underneath
            Vector3 glowPoint = points[i] - Vector3.up * 0.01f;
            vertices[i * 2]     = glowPoint - right;
            vertices[i * 2 + 1] = glowPoint + right;

            float t = (float)i / (n - 1);
            float alpha = t < 0.7f ? 1.0f : 1.0f - ((t - 0.7f) / 0.3f);
            colors[i * 2]     = new Color(1, 1, 1, alpha);
            colors[i * 2 + 1] = new Color(1, 1, 1, alpha);
        }

        int triIdx = 0;
        for (int i = 0; i < n - 1; i++)
        {
            int bl = i * 2, br = i * 2 + 1;
            int tl = (i + 1) * 2, tr = (i + 1) * 2 + 1;

            triangles[triIdx++] = bl;
            triangles[triIdx++] = tl;
            triangles[triIdx++] = br;

            triangles[triIdx++] = br;
            triangles[triIdx++] = tl;
            triangles[triIdx++] = tr;
        }

        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.colors = colors;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
    }

    private Vector3 GpsToLocalPosition(double lat, double lng, Vector3 cameraWorldPos)
    {
        const double R = 6378137.0;
        double degToRad = Math.PI / 180.0;

        double dLat = (lat - deviceLatitude) * degToRad;
        double dLng = (lng - deviceLongitude) * degToRad;

        double cosLat = Math.Cos(deviceLatitude * degToRad);
        double northMeters = dLat * R;
        double eastMeters = dLng * R * cosLat;

        float x = cameraWorldPos.x + (float)eastMeters;
        float z = cameraWorldPos.z + (float)northMeters;

        return new Vector3(x, cameraWorldPos.y, z);
    }

    private void AnimatePulse()
    {
        pulseTimer += Time.deltaTime * pulseSpeed;
        float alpha = Mathf.Lerp(minAlpha, maxAlpha, (Mathf.Sin(pulseTimer) + 1f) / 2f);

        // Pulse the main 3D line
        if (lineMaterial != null)
        {
            Color c = lineColor;
            c.a = alpha * lineColor.a;
            lineMaterial.color = c;

            // Pulse emission too
            if (lineMaterial.HasProperty("_EmissionColor"))
            {
                Color emColor = lineColor * emissionIntensity * alpha;
                lineMaterial.SetColor("_EmissionColor", emColor);
            }
        }

        // Pulse the glow
        if (glowMaterial != null)
        {
            Color c = glowColor;
            c.a = alpha * glowColor.a;
            glowMaterial.color = c;
        }
    }

    void OnDestroy()
    {
        if (lineMesh != null) Destroy(lineMesh);
        if (glowMesh != null) Destroy(glowMesh);
        if (lineMaterial != null) Destroy(lineMaterial);
        if (glowMaterial != null) Destroy(glowMaterial);
        if (lineObject != null) Destroy(lineObject);
        if (glowObject != null) Destroy(glowObject);
    }

    // JSON deserialization classes
    [Serializable]
    public class RouteCoordinate
    {
        public double lat { get; set; }
        public double lng { get; set; }
    }

    [Serializable]
    public class RoutePathMessage
    {
        public List<RouteCoordinate> coordinates { get; set; }
    }
}
