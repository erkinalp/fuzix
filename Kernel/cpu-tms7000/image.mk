tools/visualizefcc: tools/visualizefcc.c

fuzix.bin: target $(OBJS) tools/visualizefcc
	+$(MAKE) -C platform/platform-$(TARGET) image
	(cd platform/platform-$(TARGET); ../../tools/visualizefcc <../../fuzix.map)
	tools/hogfather fuzix.map | sort -nr >fuzix.hogs
