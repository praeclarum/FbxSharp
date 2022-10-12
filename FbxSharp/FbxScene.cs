using System;
using System.Runtime.InteropServices;

namespace FbxSharp
{
	public class FbxScene : IDisposable
	{
        const string LibFbxSdk = "libFbxSharpNative";

        IntPtr sceneHandle;

        bool disposedValue;

        readonly object nativeKey = new object();

        public FbxScene(string path)
        {
            lock (nativeKey)
            {
                sceneHandle = fbxLoadScene(path);
            }
        }

#if !NO_MODELIO
        public FbxScene(ModelIO.MDLAsset asset)
        {
            var errors = new Foundation.NSMutableArray();
            lock (nativeKey)
            {
                sceneHandle = fbxConvertModelIOToScene(asset.Handle, errors.Handle);
            }
        }

        public ModelIO.MDLAsset ToModelIO()
        {
            if (sceneHandle == IntPtr.Zero)
                throw new InvalidOperationException("Scene is not set");
            var allocator = new ModelIO.MDLMeshBufferDataAllocator();
            var asset = new ModelIO.MDLAsset(allocator);
            var errors = new Foundation.NSMutableArray();
            lock (nativeKey)
            {
                var assetHandle = fbxConvertSceneToModelIO(sceneHandle, asset.Handle, errors.Handle);
                if (assetHandle != asset.Handle)
                    throw new Exception("Failed to convert FBX to Model IO Asset");
                return asset;
            }
        }

        [DllImport(LibFbxSdk, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        static extern IntPtr fbxConvertSceneToModelIO(IntPtr sceneHandle, IntPtr assetHandle, IntPtr errorsHandle);

        [DllImport(LibFbxSdk, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        static extern IntPtr fbxConvertModelIOToScene(IntPtr assetHandle, IntPtr errorsHandle);
#endif

        /// <summary>
        /// Saves the scene to a file with the given format. If fileFormat is -1 then the
        /// format is determined by the path extension. If ascii is set to 1 then ASCII
        /// encoding is forced; otherwise, the default encoding is used.
        /// </summary>
        /// <param name="path">Full path to the file to export</param>
        /// <param name="fileFormat">-1 for automatic detections</param>
        /// <param name="embedMedia">1 to embed media</param>
        /// <param name="forceAscii">1 to force ASCII, otherwise use the default encoding</param>
        /// <exception cref="InvalidOperationException">If this scene object doesn't exist</exception>
        /// <exception cref="Exception">If the file fails to convert</exception>
        public void Save(string path, int fileFormat, int embedMedia, int forceAscii)
        {
            if (sceneHandle == IntPtr.Zero)
                throw new InvalidOperationException("Scene is not set");
            lock (nativeKey)
            {
                var r = fbxSaveScene(sceneHandle, path, fileFormat, embedMedia, forceAscii);
                if (r != 0)
                {
                    throw new Exception("Failed to export. Error code = " + r);
                }
            }
        }

        [DllImport(LibFbxSdk, CallingConvention = CallingConvention.Cdecl, CharSet=CharSet.Ansi)]
		static extern IntPtr fbxLoadScene(string path);

        [DllImport(LibFbxSdk, CallingConvention = CallingConvention.Cdecl, CharSet=CharSet.Ansi)]
		static extern int fbxSaveScene(IntPtr sceneHandle, string path, int fileFormat, int embedMedia, int forceAscii);

        [DllImport(LibFbxSdk, CallingConvention = CallingConvention.Cdecl, CharSet=CharSet.Ansi)]
        static extern void fbxDestroyScene(IntPtr sceneHandle);

        protected virtual void Dispose(bool disposing)
        {
            if (!disposedValue)
            {
                if (disposing)
                {
                    // Dispose managed state (managed objects)
                }

                lock (nativeKey)
                {
                    fbxDestroyScene(sceneHandle);
                }
                sceneHandle = IntPtr.Zero;
                disposedValue = true;
            }
        }

        ~FbxScene()
        {
            Dispose(disposing: false);
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}

