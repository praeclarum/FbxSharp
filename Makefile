CXX=clang++
CXXFLAGS=-std=c++11 -frtti -fexceptions -fPIC -O3 -Wall -Werror -Wno-error=unused-variable -Wno-uninitialized-const-reference
LINKFLAGS=-lxml2 -lz -liconv -framework Foundation -framework ModelIO -lfbxsdk

CSSRCS=FbxSharp/FbxScene.cs FbxSharp/Structs.cs
CPPSRCS=
MMNAMES=ConvertToModelIO.mm ConvertFromModelIO.mm FbxSharp.mm
MMSRCS=$(patsubst %,FbxSharp/%,$(MMNAMES))
SRCS=$(CPPSRCS) $(MMSRCS)

CPPOBJS=$(CPPSRCS:.cpp=.o)
MMOBJS=$(MMNAMES:.mm=.o)
OBJS=$(CPPOBJS) $(MMOBJS)

IOS_LIBS=lib/ios/arm64/libFbxSharpNative.dylib lib/iossimulator/x64/libFbxSharpNative.dylib
MACCAT_LIBS=lib/maccat/x64/libFbxSharpNative.dylib
MAC_LIBS=

LIBS=$(IOS_LIBS) $(MACCAT_LIBS) $(MAC_LIBS)

MACCAT_SYSROOT=$(shell xcrun --sdk macosx --show-sdk-path)
MAC_SYSROOT=$(shell xcrun --sdk macosx --show-sdk-path)
IOS_SYSROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOSSIM_SYSROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)

ASMS=FbxSharp/bin/Release/net6.0-ios/ios-arm64/FbxSharp.dll FbxSharp/bin/Release/net6.0-ios/iossimulator-x64/FbxSharp.dll FbxSharp/bin/Release/net6.0-maccatalyst/maccatalyst-x64/FbxSharp.dll

all: nuget

clean:
	rm -f $(LIBS)
	rm -f $(OBJS)
	rm -rf bin
	rm -rf obj
	rm -rf FbxSharp/bin
	rm -rf FbxSharp/obj


nuget: FbxSharp.nuspec FbxSharp.Native.nuspec $(ASMS) $(LIBS)
	nuget pack FbxSharp.nuspec
	nuget pack FbxSharp.Native.nuspec


managed: $(ASMS)

FbxSharp/bin/Release/net6.0-ios/ios-arm64/FbxSharp.dll: FbxSharp/FbxSharp.csproj $(CSSRCS) lib/ios/arm64/libFbxSharpNative.dylib
	dotnet build -c Release /p:TargetFrameworks=net6.0-ios /p:RuntimeIdentifier=ios-arm64 FbxSharp/FbxSharp.csproj

FbxSharp/bin/Release/net6.0-ios/iossimulator-x64/FbxSharp.dll: FbxSharp/FbxSharp.csproj $(CSSRCS) lib/iossimulator/x64/libFbxSharpNative.dylib
	dotnet build -c Release /p:TargetFrameworks=net6.0-ios /p:RuntimeIdentifier=iossimulator-x64 FbxSharp/FbxSharp.csproj

FbxSharp/bin/Release/net6.0-maccatalyst/maccatalyst-x64/FbxSharp.dll: FbxSharp/FbxSharp.csproj $(CSSRCS) lib/maccat/x64/libFbxSharpNative.dylib
	dotnet build -c Release /p:TargetFrameworks=net6.0-maccatalyst /p:RuntimeIdentifier=maccatalyst-x64 FbxSharp/FbxSharp.csproj


native: $(LIBS)

lib/ios/arm64/libFbxSharpNative.dylib: $(SRCS) FbxSharp/FbxSharp.h fbxsdk/ios/lib/ios/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	lipo fbxsdk/ios/lib/ios/libfbxsdk.a -thin arm64 -output lib/ios/arm64/libfbxsdk.a
	$(CXX) $(CXXFLAGS) $(LINKFLAGS) -shared -isysroot "$(IOS_SYSROOT)" -target arm64-apple-ios10.0 -Ifbxsdk/ios/include -Llib/ios/arm64  $(SRCS) -o $@

lib/iossimulator/x64/libFbxSharpNative.dylib: $(SRCS) FbxSharp/FbxSharp.h fbxsdk/ios/lib/iossimulator/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	cp fbxsdk/ios/lib/iossimulator/libfbxsdk.a lib/iossimulator/x64/libfbxsdk.a
	$(CXX) $(CXXFLAGS) $(LINKFLAGS) -shared -isysroot "$(IOSSIM_SYSROOT)" -stdlib=libc++ -target x86_64-apple-iossim10.0 -Ifbxsdk/ios/include -Llib/iossimulator/x64  $(SRCS) -o $@

lib/maccat/x64/libFbxSharpNative.dylib: $(SRCS) FbxSharp/FbxSharp.h fbxsdk/mac/lib/maccat/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	lipo fbxsdk/mac/lib/maccat/libfbxsdk.a -thin x86_64 -output lib/maccat/x64/libfbxsdk.a
	$(CXX) $(CXXFLAGS) $(LINKFLAGS) -shared -isysroot "$(MACCAT_SYSROOT)" -target x86_64-apple-ios13.1-macabi -Ifbxsdk/mac/include -Llib/maccat/x64  $(SRCS) -o $@

lib/mac/x64/libFbxSharp.a: $(SRCS) FbxSharp/FbxSharp.h fbxsdk/mac/lib/mac/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	lipo fbxsdk/mac/lib/mac/libfbxsdk.a -thin x86_64 -output $@
	$(CXX) $(CXXFLAGS) -arch x86_64 -Ifbxsdk/mac/include $(SRCS) -c
	$(AR) -rcs $@ $(OBJS)
	rm $(OBJS)


test: bin/nativetest
	./bin/nativetest

bin/nativetest: lib/mac/x64/libFbxSharp.a FbxSharp/NativeTest.mm
	mkdir -p bin
	$(CXX) $(CXXFLAGS) -g -Llib/mac/x64 -lFbxSharp -arch x86_64 -Ifbxsdk/mac/include -framework Foundation -framework ModelIO -lz -lxml2 -liconv -o bin/nativetest FbxSharp/NativeTest.mm

