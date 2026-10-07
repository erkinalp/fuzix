tools/visualizefcc: tools/visualizefcc.c

tools/hogfather: tools/hogfather.c

tools/pack85: tools/pack85.c

tools/packdiscard: tools/packdiscard.c

tools/doubleup: tools/doubleup.c

tools/makejv3: tools/makejv3.c

tools/trslabel: tools/trslabel.c

tools/makedck: tools/makedck.c

tools/plus3boot: tools/plus3boot.c

tools/raw2dsk: tools/raw2dsk.c

cpm-loader-fcc/cpmload.bin: cpm-loader-fcc/cpmload.S cpm-loader-fcc/fuzixload.S cpm-loader-fcc/makecpmloader.c
	+$(MAKE) -C cpm-loader-fcc

fuzix.bin: target $(OBJS) tools/pack85 tools/packdiscard tools/visualizefcc tools/doubleup cpm-loader-fcc/cpmload.bin tools/makejv3 tools/trslabel tools/hogfather tools/makedck tools/plus3boot tools/raw2dsk
	+$(MAKE) -C platform/platform-$(TARGET) image
	(cd platform/platform-$(TARGET); ../../tools/visualizefcc <../../fuzix.map)
	tools/hogfather fuzix.map | sort -nr >fuzix.hogs
