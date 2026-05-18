class GitlabBar < Formula
  desc "macOS menu bar widget showing GitLab CI/CD pipeline status"
  homepage "https://github.com/ncthanhngo/gitlab-bar"
  url "https://github.com/ncthanhngo/gitlab-bar/archive/refs/tags/v0.5.0.tar.gz"
  sha256 "f87c3cd13adcdd35e8053cc9f14ed12c262659bb7fdd4b7b69b123b7b2c42946"
  license "MIT"
  head "https://github.com/ncthanhngo/gitlab-bar.git", branch: "main"

  depends_on "xcodegen" => :build
  depends_on xcode: ["15.0", :build]
  depends_on :macos

  def install
    cd "GitLabBar" do
      system "xcodegen", "generate"
      system "xcodebuild",
             "-project", "GitLabBar.xcodeproj",
             "-scheme", "GitLabBar",
             "-configuration", "Release",
             "-derivedDataPath", "build",
             "CODE_SIGN_IDENTITY=-",
             "CODE_SIGNING_REQUIRED=NO",
             "CODE_SIGNING_ALLOWED=NO",
             "build"
      prefix.install "build/Build/Products/Release/GitLabBar.app"
    end

    # Tiny launcher so `brew install gitlab-bar` puts something on the PATH.
    (bin/"gitlab-bar").write <<~SHELL
      #!/bin/bash
      exec open -a "#{prefix}/GitLabBar.app" "$@"
    SHELL
    chmod 0755, bin/"gitlab-bar"
  end

  def caveats
    <<~EOS
      GitLabBar is a menu bar app. After install, launch it once with:
        gitlab-bar
      Then click the icon in the menu bar to open Settings and add your
      self-hosted GitLab URL, Personal Access Token, and projects.
    EOS
  end

  test do
    assert_predicate prefix/"GitLabBar.app", :exist?
  end
end
