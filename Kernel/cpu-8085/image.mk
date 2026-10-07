tools/visualizefcc: tools/visualizefcc.c

tools/pack85: tools/pack85.c

fuzix.bin: target $(OBJS) tools/pack85 tools/visualizefcc
	+$(MAKE) -C platform/platform-$(TARGET) image
	(cd platform/platform-$(TARGET); ../../tools/visualizefcc <../../fuzix.map)
	tools/hogfather fuzix.map | sort -nr >fuzix.hogs
