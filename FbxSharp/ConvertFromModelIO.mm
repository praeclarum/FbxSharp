#include "FbxSharp.h"
#import <ModelIO/ModelIO.h>

#include <objc/runtime.h>

#define objc_dynamic_cast(obj, cls) \
    ([obj isKindOfClass:(Class)objc_getClass(#cls)] ? (cls *)obj : NULL)

FbxMesh *mdlMeshToFbxMesh(MDLMesh *mesh, FbxScene *scene, FbxManager *manager, NSMutableArray *errors) {
    FbxMesh *fbxMesh = FbxMesh::Create(manager, "mdlMesh");
    if (!fbxMesh) {
        return NULL;
    }

    NSArray<id<MDLMeshBuffer>> *vertexBuffers = mesh.vertexBuffers;
    NSLog(@"vertexBuffers: %@", vertexBuffers);
    NSUInteger vertexCount = mesh.vertexCount;
    NSLog(@"vertexCount: %lu", vertexCount);
    auto vertexAttributes = mesh.vertexDescriptor.attributes;
    // NSLog(@"vertexAttributes: %@", vertexAttributes);
    auto vertexLayouts = mesh.vertexDescriptor.layouts;
    // NSLog(@"vertexLayouts: %@", vertexLayouts);

    // Set control points
    MDLVertexAttribute *positionAttribute = nil;
    for (MDLVertexAttribute *attribute in vertexAttributes) {
        if (attribute.name == MDLVertexAttributePosition) {
            positionAttribute = attribute;
            break;
        }
    }
    if (positionAttribute) {
        if (positionAttribute.format != MDLVertexFormatFloat3) {
            [errors addObject:@"Position attribute is not float3"];
            fbxMesh->Destroy();
            return NULL;
        }
        NSLog(@"positionAttribute: %@", positionAttribute);
        fbxMesh->InitControlPoints(vertexCount);
        FbxVector4* controlPoints = fbxMesh->GetControlPoints();
        NSLog(@"controlPoints: %p", controlPoints);
        auto vertexBuffer = vertexBuffers[positionAttribute.bufferIndex];
        auto vertexLayout = vertexLayouts[positionAttribute.bufferIndex];
        auto vertexStride = vertexLayout.stride;
        auto offset = positionAttribute.offset;
        @autoreleasepool {
            auto map = [vertexBuffer map];
            char *vertexData = (char*)map.bytes;
            for (NSUInteger i = 0; i < vertexCount; i++) {
                char *positionData = vertexData + i * vertexStride + offset;
                auto pt = FbxVector4(
                    *(float *)(positionData + 0 * sizeof(float)),
                    *(float *)(positionData + 1 * sizeof(float)),
                    *(float *)(positionData + 2 * sizeof(float))
                );
                // NSLog(@"pt%lu/%lu: %g, %g, %g", i, vertexCount, pt.mData[0], pt.mData[1], pt.mData[2]);
                controlPoints[i] = pt;
            }
        }
    }
    else {
        [errors addObject:@"No position attribute on mesh"];
        fbxMesh->Destroy();
        return NULL;
    }

    // Set normals
    MDLVertexAttribute *normalAttribute = nil;
    for (MDLVertexAttribute *attribute in vertexAttributes) {
        if (attribute.name == MDLVertexAttributeNormal) {
            normalAttribute = attribute;
            break;
        }
    }
    if (normalAttribute && normalAttribute.format == MDLVertexFormatFloat3) {
        NSLog(@"normalAttribute: %@", normalAttribute);
        FbxLayerElementNormal *fbxNormal = fbxMesh->CreateElementNormal();
        fbxNormal->SetMappingMode(FbxLayerElement::eByControlPoint);
        fbxNormal->SetReferenceMode(FbxLayerElement::eDirect);
        fbxNormal->GetDirectArray().SetCount(vertexCount);
        auto vertexBuffer = vertexBuffers[normalAttribute.bufferIndex];
        auto vertexLayout = vertexLayouts[normalAttribute.bufferIndex];
        auto vertexStride = vertexLayout.stride;
        auto offset = normalAttribute.offset;
        @autoreleasepool {
            auto map = [vertexBuffer map];
            char *vertexData = (char*)map.bytes;
            for (NSUInteger i = 0; i < vertexCount; i++) {
                char *normalData = vertexData + i * vertexStride + offset;
                auto normal = FbxVector4(
                    *(float *)(normalData + 0 * sizeof(float)),
                    *(float *)(normalData + 1 * sizeof(float)),
                    *(float *)(normalData + 2 * sizeof(float))
                );
                // NSLog(@"normal%lu/%lu: %g, %g, %g", i, vertexCount, normal.mData[0], normal.mData[1], normal.mData[2]);
                fbxNormal->GetDirectArray().SetAt(i, normal);
            }
        }
    }

    // Set UVs
    MDLVertexAttribute *uvAttribute = nil;
    for (MDLVertexAttribute *attribute in vertexAttributes) {
        if (attribute.name == MDLVertexAttributeTextureCoordinate) {
            uvAttribute = attribute;
            break;
        }
    }
    if (uvAttribute && uvAttribute.format == MDLVertexFormatFloat2) {
        NSLog(@"uvAttribute: %@", uvAttribute);
        FbxLayerElementUV *fbxUV = fbxMesh->CreateElementUV("DiffuseUV");
        fbxUV->SetMappingMode(FbxLayerElement::eByControlPoint);
        fbxUV->SetReferenceMode(FbxLayerElement::eDirect);
        fbxUV->GetDirectArray().SetCount(vertexCount);
        auto vertexBuffer = vertexBuffers[uvAttribute.bufferIndex];
        auto vertexLayout = vertexLayouts[uvAttribute.bufferIndex];
        auto vertexStride = vertexLayout.stride;
        auto offset = uvAttribute.offset;
        @autoreleasepool {
            auto map = [vertexBuffer map];
            char *vertexData = (char*)map.bytes;
            for (NSUInteger i = 0; i < vertexCount; i++) {
                char *uvData = vertexData + i * vertexStride + offset;
                auto uv = FbxVector2(
                    *(float *)(uvData + 0 * sizeof(float)),
                    *(float *)(uvData + 1 * sizeof(float))
                );
                // NSLog(@"uv%lu/%lu: %g, %g", i, vertexCount, uv.mData[0], uv.mData[1]);
                fbxUV->GetDirectArray().SetAt(i, uv);
            }
        }
    }

    // Add submeshes
    for (MDLSubmesh *submesh in [mesh submeshes]) {
        NSLog(@"submesh: %@", submesh);
        const MDLGeometryType geometryType = submesh.geometryType;
        const auto n = submesh.indexCount;
        //MDLMaterial *material = submesh.material;
        NSLog(@"submesh.indexCount: %lu", n);
        NSLog(@"submesh.indexType: %lu", submesh.indexType);
        NSLog(@"submesh.geometryType: %lu", geometryType);
        NSLog(@"submesh.indexBuffer: %@", submesh.indexBuffer);
        auto indexBuffer = [submesh indexBufferAsIndexType:MDLIndexBitDepthUInt32];
        NSLog(@"submesh.indexBuffer32: %@", indexBuffer);
        const int polygonGroup = -1;
        switch (submesh.geometryType) {
            case MDLGeometryTypePoints:
                [errors addObject:@"Points not supported"];
                break;
            case MDLGeometryTypeLines:
                [errors addObject:@"Lines not supported"];
                break;
            case MDLGeometryTypeTriangles:
                @autoreleasepool {
                    auto map = [indexBuffer map];
                    uint32_t *indexData = (uint32_t*)map.bytes;
                    for (NSUInteger i = 0; i < n; ) {
                        fbxMesh->BeginPolygon(-1, -1, polygonGroup, false);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->EndPolygon();
                    }
                }
                break;
            case MDLGeometryTypeTriangleStrips:
                [errors addObject:@"Triangle strips not supported"];
                break;
            case MDLGeometryTypeQuads:
                @autoreleasepool {
                    auto map = [indexBuffer map];
                    uint32_t *indexData = (uint32_t*)map.bytes;
                    for (NSUInteger i = 0; i < n; ) {
                        fbxMesh->BeginPolygon(-1, -1, polygonGroup, false);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->AddPolygon(indexData[i++]);
                        fbxMesh->EndPolygon();
                    }
                }
                break;
            case MDLGeometryTypeVariableTopology:
                [errors addObject:@"Variable topology not supported"];
                break;
            default:
                [errors addObject:@"Unknown geometry type"];
                break;
        }
        NSLog(@"submesh.indexBuffer: %@", submesh.indexBuffer);
    }
    return fbxMesh;
}

FbxNode *mdlObjectToFbxNode(MDLObject *obj, FbxScene *scene, FbxManager *manager, NSMutableArray *errors)
{
    NSLog(@"Converting MDLObject %@ to FbxNode", obj);

    FbxNode *node = FbxNode::Create(scene, obj.name.UTF8String);

    FbxNodeAttribute *attribute = nil;
    MDLMesh *mesh = objc_dynamic_cast(obj, MDLMesh);
    if (mesh) {
        FbxMesh *fbxMesh = mdlMeshToFbxMesh(mesh, scene, manager, errors);
        if (!fbxMesh) {
            [errors addObject:@"Failed to convert mesh"];
        }
        attribute = fbxMesh;
    }

    if (!attribute) {
        attribute = FbxNull::Create(scene, "");
    }

    node->SetNodeAttribute(attribute);

    // node->SetTransform(mdlTransformToFbxMatrix(obj.transform));
    node->SetVisibility(obj.hidden ? 0 : 1);

    for (MDLObject *child in obj.children) {
        FbxNode *childNode = mdlObjectToFbxNode(child, scene, manager, errors);
        node->AddChild(childNode);
    }
    return node;
}

extern "C" {

FbxScene *fbxConvertModelIOToScene(MDLAsset *asset, NSMutableArray *errors)
{
    NSLog(@"Converting from ModelIO asset %p", asset);

    FbxScene *scene = NULL;
    InitializeSdkObjects(TheSdkManager, scene, "SceneFromMDLAsset");
    FbxManager *manager = TheSdkManager;

    if (!scene) {
        NSLog(@"Cannot create scene scene to convert");
        return nil;
    }

    auto rootNode = scene->GetRootNode();
    if (!rootNode) {
        NSLog(@"Cannot get root node to convert");
        return nil;
    }

    NSLog(@"Asset contains %lu objects", asset.count);
    for (NSUInteger i = 0; i < [asset count]; i++) {
        auto obj = [asset objectAtIndex:i];

        auto objNode = mdlObjectToFbxNode(obj, scene, manager, errors);
        if (!objNode) {
            NSLog(@"Cannot convert object at index %lu to node", i);
            return nil;
        }

        rootNode->AddChild(objNode);
    }

    NSLog(@"Conversion errors: %@", errors);

    return scene;
}

}
