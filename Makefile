.PHONY: all clean build

all: clean build

build:
	xcodebuild build -scheme LoosePhabric

clean:
	xcodebuild clean
	rm -rf LoosePhabric.xcarchive

archive:
	xcodebuild clean archive -scheme LoosePhabric -archivePath LoosePhabric

#package:
#	xcodebuild -exportArchive -archivePath "LoosePhabric.xcarchive" -exportPath Release --exportOptionsPlist [file]
