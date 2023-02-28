if [ "$(uname -s)" == "Darwin" ]; then
    xcode-select --install

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install)"

    brew install coreutils curl git openssl@3 readline libyaml gmp

    brew install asdf

    echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ${ZDOTDIR:-~}/.zshrc

    . ${ZDOTDIR:-~}/.zshrc

    asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git

    asdf install ruby 3.0.1

    gem install bundler

    bundle
fi
