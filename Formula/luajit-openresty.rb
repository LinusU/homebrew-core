class LuajitOpenresty < Formula
  desc "OpenResty's Branch of LuaJIT 2"
  homepage "https://github.com/openresty/luajit2"
  url "https://github.com/openresty/luajit2/archive/v2.1-20201229.tar.gz"
  sha256 "4275bf97356d713826e7195d1c330568b6089ff1fd4c6954f998e0f60a2baa30"
  license "MIT"
  head "https://github.com/openresty/luajit2.git", branch: "v2.1-agentzh"

  bottle do
    cellar :any
    sha256 "9fa20c915d38bc34cf61def4820d6f07e7bf16f1a2e01a8a2a80db6ba3f7567e" => :big_sur
    sha256 "60153b2fbc7fe9735802e9c603b07f811713a3f7afc3af1f5662e9abebee3a96" => :arm64_big_sur
    sha256 "ff62b7661154ef6b28e686dd5a5f50c732f375b67700b7aa285ef6d01b91987c" => :catalina
    sha256 "6ba231a307a5ff68374d543b8a8a59eedb2b35228f4e822f666a187c16ef16d3" => :mojave
  end

  keg_only "it conflicts with the LuaJIT formula"

  def install
    # 1 - Override the hardcoded gcc.
    # 2 - Remove the "-march=i686" so we can set the march in cflags.
    # Both changes should persist and were discussed upstream.
    inreplace "src/Makefile" do |f|
      f.change_make_var! "CC", ENV.cc
      f.change_make_var! "CCOPT_x86", ""
    end

    # Per https://luajit.org/install.html: If MACOSX_DEPLOYMENT_TARGET
    # is not set then it's forced to 10.4, which breaks compile on Mojave.
    ENV["MACOSX_DEPLOYMENT_TARGET"] = MacOS.version

    args = %W[
      PREFIX=#{prefix}
      XCFLAGS=-DLUAJIT_ENABLE_GC64
    ]

    system "make", "amalg", *args
    system "make", "install", *args

    # LuaJIT doesn't automatically symlink unversioned libraries:
    # https://github.com/Homebrew/homebrew/issues/45854.
    lib.install_symlink lib/"libluajit-5.1.dylib" => "libluajit.dylib"
    lib.install_symlink lib/"libluajit-5.1.a" => "libluajit.a"

    # Fix path in pkg-config so modules are installed
    # to permanent location rather than inside the Cellar.
    inreplace lib/"pkgconfig/luajit.pc" do |s|
      s.gsub! "INSTALL_LMOD=${prefix}/share/lua/${abiver}",
              "INSTALL_LMOD=#{HOMEBREW_PREFIX}/share/lua/${abiver}"
      s.gsub! "INSTALL_CMOD=${prefix}/${multilib}/lua/${abiver}",
              "INSTALL_CMOD=#{HOMEBREW_PREFIX}/${multilib}/lua/${abiver}"
      unless build.head?
        s.gsub! "Libs:",
                "Libs: -pagezero_size 10000 -image_base 100000000"
      end
    end

    # Having an empty Lua dir in lib/share can mess with other Homebrew Luas.
    %W[#{lib}/lua #{share}/lua].each { |d| rm_rf d }
  end

  test do
    system "#{bin}/luajit", "-e", <<~EOS
      local ffi = require("ffi")
      ffi.cdef("int printf(const char *fmt, ...);")
      ffi.C.printf("Hello %s!\\n", "#{ENV["USER"]}")
    EOS
  end
end
