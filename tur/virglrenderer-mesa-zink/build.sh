TERMUX_PKG_HOMEPAGE=https://virgil3d.github.io/
TERMUX_PKG_DESCRIPTION="A virtual 3D GPU for use inside qemu virtual machines"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
TERMUX_PKG_VERSION=1.0.1
TERMUX_PKG_SRCURL=https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/virglrenderer-${TERMUX_PKG_VERSION[0]}/virglrenderer-virglrenderer-${TERMUX_PKG_VERSION[0]}.tar.gz
TERMUX_PKG_DEPENDS="angle-android, libdrm, libepoxy, libglvnd, libx11, mesa, vulkan-loader"
TERMUX_PKG_SHA256=446ab3e265f574ec598e77bdfbf0616ee3c77361f0574bec733ba4bac4df730a
TERMUX_PKG_BUILD_DEPENDS="xorgproto"
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="-Dplatforms=egl,glx -Dvenus=true"
termux_step_pre_configure() {
	# error: using an array subscript expression within 'offsetof' is a Clang extension [-Werror,-Wgnu-offsetof-extensions]
	# list_for_each_entry_safe(struct vrend_linked_shader_program, ent, &shader->programs, sl[shader->sel->type])
	CPPFLAGS+=" -Wno-error=gnu-offsetof-extensions"
}
# Ref: https://github.com/ThieuMinh26/Proot-Setup/blob/25edeff7b45feffc4117276ef8245e94f7682766/Zink
termux_step_make_install() {
	sed "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" \
		$TERMUX_PKG_BUILDER_DIR/virgl_test_server_android.in > \
		$TERMUX_PREFIX/bin/virgl_test_server_android
	chmod +x $TERMUX_PREFIX/bin/virgl_test_server_android
}

termux_step_install_license() {
	mkdir -p $TERMUX_PREFIX/share/doc/$TERMUX_PKG_NAME
	cp $TERMUX_PKG_SRCDIR/COPYING $TERMUX_PREFIX/share/doc/$TERMUX_PKG_NAME/COPYING-virglrenderer
#	cp $TERMUX_PKG_SRCDIR/libepoxy/COPYING $TERMUX_PREFIX/share/doc/$TERMUX_PKG_NAME/COPYING-libepoxy
	cp $TERMUX_PKG_BUILDER_DIR/COPYING-gl4es $TERMUX_PREFIX/share/doc/$TERMUX_PKG_NAME/COPYING-gl4es
}
