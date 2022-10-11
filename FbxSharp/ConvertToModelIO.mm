#include "FbxSharp.h"
#import <ModelIO/ModelIO.h>

static void dumpFbxNode(FbxNode *node, int level)
{
    for (int i = 0; i < level; i++)
        printf("  ");
    printf("Node %s\n", node->GetName());
    for (int i = 0; i < node->GetNodeAttributeCount(); i++)
    {
        FbxNodeAttribute *attr = node->GetNodeAttributeByIndex(i);
        auto attrType = attr->GetAttributeType();
        printf("  Attribute %d %s: %d has %d nodes\n", i, attr->GetName(), (int)attrType, attr->GetNodeCount());
        // for (int j = 0; j < attr->GetNodeCount(); j++) {
        //     FbxNode *child = attr->GetNode(j);
        //     dumpFbxNode(child, level + 2);
        // }
    }
    for (int i = 0; i < node->GetChildCount(); i++)
        dumpFbxNode(node->GetChild(i), level + 1);
}

static MDLMesh *fbxMeshToMDLMesh(FbxMesh *mesh, MDLMeshBufferDataAllocator *allocator)
{
    const int numTriangles = mesh->GetPolygonCount();
    const int *indexes = mesh->GetPolygonVertices();
    const int numVertices = mesh->GetControlPointsCount();
    const FbxVector4 *controlPoints = mesh->GetControlPoints();
    NSLog(@"Mesh: %s, numTriangles: %d, numVertices: %d", mesh->GetName(), numTriangles, numVertices);
    
    int numElementNormals = mesh->GetElementNormalCount();
    NSLog(@"numElementNormals: %d", numElementNormals);
    bool hasNormals = numElementNormals > 0;
    int numNormals = 0;
    if (hasNormals) {
        auto normals = mesh->GetElementNormal(0);
        auto &normalsArray = normals->GetDirectArray();
        numNormals = normalsArray.GetCount();
        NSLog(@"numNormals: %d", numNormals);
    }
    if (numNormals != numVertices) {
        NSLog(@"Generating normals");
        mesh->GenerateNormals(true, true, false);
        numElementNormals = mesh->GetElementNormalCount();
        NSLog(@"numElementNormals: %d", numElementNormals);
        hasNormals = numElementNormals > 0;
   }
 
    NSLog(@"Outputting buffers");
    NSUInteger vertexBufferSize = 24 * numVertices;
    NSUInteger indexBufferSize = sizeof(int) * 3 * numTriangles;
    id<MDLMeshBuffer> vertexBuffer = [allocator newBuffer:vertexBufferSize type:MDLMeshBufferTypeVertex];
    float *vertexFloats = new float[6*numVertices];

    if (hasNormals) {
        auto normals = mesh->GetElementNormal(0);
        auto &normalsArray = normals->GetDirectArray();
        numNormals = normalsArray.GetCount();
        NSLog(@"numNormals: %d", numNormals);
        hasNormals = numNormals == numVertices;
        if (hasNormals) {
            for (int i = 0, p = 3; i < numNormals; i++) {
                auto v = normalsArray[i];
                vertexFloats[p++] = v[0];
                vertexFloats[p++] = v[1];
                vertexFloats[p++] = v[2];
                p += 3;
            }
        }
    }
    int poff = hasNormals ? 3 : 0;

    for (int i = 0, p = 0; i < numVertices; i++) {
        FbxVector4 v = controlPoints[i];
        vertexFloats[p++] = v[0];
        vertexFloats[p++] = v[1];
        vertexFloats[p++] = v[2];
        p += poff;
    }
    auto vertexData = [NSData dataWithBytes:vertexFloats length:vertexBufferSize];
    [vertexBuffer fillData:vertexData offset:0];
    delete[] vertexFloats;
    id<MDLMeshBuffer> indexBuffer = [allocator newBuffer:indexBufferSize type:MDLMeshBufferTypeIndex];
    auto indexData = [NSData dataWithBytes:indexes length:indexBufferSize];
    [indexBuffer fillData:indexData offset:0];

    MDLVertexDescriptor *descriptor = [[MDLVertexDescriptor alloc] init];
    MDLVertexAttribute *pos = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributePosition 
                                                            format:MDLVertexFormatFloat3
                                                            offset:0
                                                            bufferIndex:0];
    [descriptor addOrReplaceAttribute:pos];
    if (hasNormals) {
        MDLVertexAttribute *norm = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributeNormal 
                                                            format:MDLVertexFormatFloat3
                                                            offset:12
                                                            bufferIndex:0];
        [descriptor addOrReplaceAttribute:norm];
    }
    [descriptor setPackedOffsets];
    [descriptor setPackedStrides];
    // NSLog(@"Vertex Descriptor: %@", descriptor);

    MDLSubmesh *submesh = [[MDLSubmesh alloc] initWithIndexBuffer:indexBuffer 
                                                indexCount:numTriangles * 3
                                                indexType:MDLIndexBitDepthUInt32
                                                geometryType:MDLGeometryTypeTriangles
                                                material:nil];
    MDLMesh *mdlMesh = [[MDLMesh alloc] initWithVertexBuffer:vertexBuffer 
                        vertexCount:numVertices
                        descriptor:descriptor 
                        submeshes:@[submesh]];
    return mdlMesh;
}

static MDLTransform *fbxMatrixToMDLTransform(FbxAMatrix &m)
{
    FbxVector4 row0 = m.GetRow(0);
    FbxVector4 row1 = m.GetRow(1);
    FbxVector4 row2 = m.GetRow(2);
    FbxVector4 row3 = m.GetRow(3);
    matrix_float4x4 m4x4 = simd_matrix_from_rows(
        simd_make_float4(row0[0], row0[1], row0[2], row0[3]),
        simd_make_float4(row1[0], row1[1], row1[2], row1[3]),
        simd_make_float4(row2[0], row2[1], row2[2], row2[3]),
        simd_make_float4(row3[0], row3[1], row3[2], row3[3])
    );
    MDLTransform *transform = [[MDLTransform alloc] initWithMatrix: m4x4 resetsTransform: YES];
    return transform;
}

static MDLObject *fbxNodeToMDLObject(FbxNode *node, int level, MDLMeshBufferDataAllocator *allocator)
{
    for (int i = 0; i < level; i++)
        printf("  ");
    printf("FbxNode To MDLObject: %s\n", node->GetName());

    MDLObject *thisObj = nil;

    FbxMesh *mesh = node->GetMesh();

    if (mesh) {        
        thisObj = fbxMeshToMDLMesh(mesh, allocator);
    }

    // Catch failures or empty objects
    if (!thisObj) {
        thisObj = [[MDLObject alloc] init];
    }

    thisObj.name = [NSString stringWithUTF8String: node->GetName()];
    thisObj.transform = fbxMatrixToMDLTransform(node->EvaluateLocalTransform());
    thisObj.hidden = node->GetVisibility() == 0;

    for (int i = 0; i < node->GetChildCount(); i++) {
        auto childObj = fbxNodeToMDLObject(node->GetChild(i), level + 1, allocator);
        if (childObj) {
            [thisObj addChild:childObj];
        }
    }

    return thisObj;
}

extern "C" {

MDLAsset *fbxConvertSceneToModelIO(FbxScene *scene, MDLAsset *asset, NSMutableArray *errors)
{
    NSLog(@"Converting scene %p to ModelIO asset %p", scene, asset);
    FbxManager *manager = TheSdkManager;
    if (!scene) {
        NSLog(@"No scene to convert");
        return nil;
    }

    dumpFbxNode(scene->GetRootNode(), 0);

    NSLog(@"Triangulating");
    FbxGeometryConverter converter(manager);
    converter.Triangulate(scene, true);

    NSLog(@"Getting ModelIO objects");
    @autoreleasepool {
        MDLMeshBufferDataAllocator *allocator = [asset bufferAllocator];
        MDLObject *rootObject = fbxNodeToMDLObject(scene->GetRootNode(), 0, allocator);
        [asset addObject:rootObject];
    }
    
    return asset;
}

}
