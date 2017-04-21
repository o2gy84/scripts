### RPM/DEB packager
Allow to build rpm/deb packages so easy as 123

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

