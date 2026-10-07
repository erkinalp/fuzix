CROSS_CCOPTS += -Os
# We have a right mess to deal with because of the paging locking bugs
# on the UNO. No code 1FF8-1FFF or 3D00-3DFF!
