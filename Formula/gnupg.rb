class Gnupg < Formula
  desc "GNU Pretty Good Privacy (PGP) package"
  homepage "https://gnupg.org/"
  url "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.27.tar.bz2"
  sha256 "34e60009014ea16402069136e0a5f63d9b65f90096244975db5cea74b3d02399"
  license "GPL-3.0-or-later"
  revision 1

  livecheck do
    url "https://gnupg.org/ftp/gcrypt/gnupg/"
    regex(/href=.*?gnupg[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 "6726388722ce3b72733bb9b685c7325a42bfa277b54fadf5c5994a3396b3c35f" => :big_sur
    sha256 "e43d39b6d1eb7ed8451ef71fd9ccc37a2505e0c04a68e89290fcd9add362f228" => :arm64_big_sur
    sha256 "f7e22bee02f43a65794ab1b2bb44bc9650a634fdc2002a102106e78b6c32d2a8" => :catalina
    sha256 "7250d3b3429e984579c1a1cde3455f63981c3a29d17d23eadce5c45079199bbf" => :mojave
  end

  depends_on "pkg-config" => :build
  depends_on "adns"
  depends_on "gettext"
  depends_on "gnutls"
  depends_on "libassuan"
  depends_on "libgcrypt"
  depends_on "libgpg-error"
  depends_on "libksba"
  depends_on "libusb"
  depends_on "npth"
  depends_on "pinentry"

  # This patch is a workaround for a bug in gpg-agent when a wrong password from the cache is returned by
  # pinentry-mac. Without this patch, the agent would let pinentry-mac remove the password from the cache and return
  # a BAD_PASSPHRASE error. With this patch, the agent asks pinentry-mac again to get a password from the user.
  patch do
    url "https://raw.githubusercontent.com/GPGTools/MacGPG2/7770678e923741ca6d9f0f1a4d5cdf3971250754/patches/gnupg/agent-cache-bug-workaround.patch"
    sha256 "c68158c7f7f1a6bceed9a8e2f429faf3c83d75e6144e16a6c2ed0fdce4a2e17f"
  end

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--sbindir=#{bin}",
                          "--sysconfdir=#{etc}",
                          "--enable-all-tests",
                          "--enable-symcryptrun",
                          "--with-pinentry-pgm=#{Formula["pinentry"].opt_bin}/pinentry"
    system "make"
    system "make", "check"
    system "make", "install"
  end

  def post_install
    (var/"run").mkpath
    quiet_system "killall", "gpg-agent"
  end

  test do
    (testpath/"batch.gpg").write <<~EOS
      Key-Type: RSA
      Key-Length: 2048
      Subkey-Type: RSA
      Subkey-Length: 2048
      Name-Real: Testing
      Name-Email: testing@foo.bar
      Expire-Date: 1d
      %no-protection
      %commit
    EOS
    begin
      system bin/"gpg", "--batch", "--gen-key", "batch.gpg"
      (testpath/"test.txt").write "Hello World!"
      system bin/"gpg", "--detach-sign", "test.txt"
      system bin/"gpg", "--verify", "test.txt.sig"
    ensure
      system bin/"gpgconf", "--kill", "gpg-agent"
    end
  end
end
