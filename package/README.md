### RPM/DEB packager
Allow to build rpm/deb packages so easy as 123  
1) simple_pkg_builder.py: just build package as is
2) pkg_builder.py: build both dev-package with only headers and package with files, libraries e.t.c.

## Before usage:
_Ubuntu:_  
```
sudo apt-get install ruby-dev build-essential
sudo gem install fpm
```

_CentOS:_
```
sudo yum install ruby rubygems ruby-dev (or ruby-devel)
sudo gem install fpm
```

## Usage:
1) need to edit script - fill actual paths to headers, libs and other files/dirs
2) launch script:
```
pkg_builder.py rpm  # rpm 
pkg_builder.py deb  # deb
```

