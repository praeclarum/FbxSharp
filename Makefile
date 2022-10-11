CXX=clang++
CXXFLAGS=-std=c++11 -frtti -fexceptions -fPIC -O3 -Wall -Werror -Wno-error=unused-variable -Wno-uninitialized-const-reference

CPPSRCS=
MMNAMES=ConvertToModelIO.mm ConvertFromModelIO.mm FbxSharp.mm
MMSRCS=$(patsubst %,FbxSharp/%,$(MMNAMES))
SRCS=$(CPPSRCS) $(MMSRCS)

CPPOBJS=$(CPPSRCS:.cpp=.o)
MMOBJS=$(MMNAMES:.mm=.o)
OBJS=$(CPPOBJS) $(MMOBJS)

IOS_LIBS=lib/ios/arm64/libFbxSharp.a lib/iossimulator/x64/libFbxSharp.a
MACCAT_LIBS=lib/maccat/x64/libFbxSharp.a
MAC_LIBS=lib/mac/x64/libFbxSharp.a

LIBS=$(IOS_LIBS) $(MACCAT_LIBS) $(MAC_LIBS)

MACCAT_SYSROOT=$(shell xcrun --sdk macosx --show-sdk-path)
MAC_SYSROOT=$(shell xcrun --sdk macosx --show-sdk-path)
IOS_SYSROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOSSIM_SYSROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)

CONFIG=Debug

all: buildnative

buildnative: $(LIBS)

buildnet: FbxSharp/FbxSharp.csproj FbxSharp/FbxScene.cs $(LIBS)
	dotnet build -c $(CONFIG)
#	dotnet restore -r iossimulator-x64
#	dotnet build --no-restore --no-self-contained -c $(CONFIG) -f net6.0-ios -r iossimulator-x64

libs: $(LIBS)

clean:
	rm -f $(LIBS)
	rm -f $(OBJS)
	rm -rf bin
	rm -rf obj

lib/ios/arm64/libFbxSharp.a: $(SRCS) FbxSharp/FbxSharp.h Makefile fbxsdk/ios/lib/ios/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	lipo fbxsdk/ios/lib/ios/libfbxsdk.a -thin arm64 -output $@
	$(CXX) $(CXXFLAGS) -isysroot "$(IOS_SYSROOT)" -target arm64-apple-ios10.0 -Ifbxsdk/ios/include $(SRCS) -c
	$(AR) -rcs $@ $(OBJS)
	rm $(OBJS)

lib/iossimulator/x64/libFbxSharp.a: $(SRCS) FbxSharp/FbxSharp.h Makefile fbxsdk/ios/lib/iossimulator/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	cp fbxsdk/ios/lib/iossimulator/libfbxsdk.a $@
	$(CXX) $(CXXFLAGS) -isysroot "$(IOSSIM_SYSROOT)" -stdlib=libc++ -target x86_64-apple-iossim10.0 -Ifbxsdk/ios/include $(SRCS) -c
	$(AR) -rcs $@ $(OBJS)
	rm $(OBJS)

lib/maccat/x64/libFbxSharp.a: $(SRCS) FbxSharp/FbxSharp.h Makefile fbxsdk/mac/lib/maccat/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	lipo fbxsdk/mac/lib/maccat/libfbxsdk.a -thin x86_64 -output $@
	$(CXX) $(CXXFLAGS) -target x86_64-apple-ios13.1-macabi -Ifbxsdk/mac/include $(SRCS) -c
	$(AR) -rcs $@ $(OBJS)
	rm $(OBJS)

lib/mac/x64/libFbxSharp.a: $(SRCS) FbxSharp/FbxSharp.h Makefile fbxsdk/mac/lib/mac/libfbxsdk.a
	mkdir -p $(dir $@)
	rm -f $@
	lipo fbxsdk/mac/lib/mac/libfbxsdk.a -thin x86_64 -output $@
	$(CXX) $(CXXFLAGS) -arch x86_64 -Ifbxsdk/mac/include $(SRCS) -c
	$(AR) -rcs $@ $(OBJS)
	rm $(OBJS)

bin/nativetest: lib/mac/x64/libFbxSharp.a FbxSharp/NativeTest.mm
	mkdir -p bin
	$(CXX) $(CXXFLAGS) -g -Llib/mac/x64 -lFbxSharp -arch x86_64 -Ifbxsdk/mac/include -framework Foundation -framework ModelIO -lz -lxml2 -liconv -o bin/nativetest NativeTest.mm

test: bin/nativetest
	./bin/nativetest
