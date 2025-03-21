FROM centos:centos7.9.2009
ADD https://raw.githubusercontent.com/AtlasGondal/centos7-eol-repo-fix/refs/heads/main/CentOS-Base.repo /etc/yum.repos.d
COPY vault-scl.repo /etc/yum.repos.d/
RUN yum install -y epel-release
RUN yum clean all && yum makecache
RUN yum update -y

#
# Install tools needed by tebako
#

# Install devtoolset-11 stuff
RUN    yum install -y devtoolset-11 devtoolset-11-elfutils-libelf-devel

# Set environment variables for devtoolset-11
RUN echo "source /opt/rh/devtoolset-11/enable" >> /etc/profile.d/devtoolset-11.sh

# Verify installation (optional)
RUN bash -c "source /opt/rh/devtoolset-11/enable && gcc --version"

# Install cmake
ARG CMAKE_VERSION=3.24.4
RUN mkdir -p /usr/local/cmake && curl -Ls https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz | tar xz -C /usr/local/cmake --strip-components 1 && \
    ln -s /usr/local/cmake/bin/cmake /usr/bin

# RPMs

RUN yum install -y sudo git curl @Development pkgconfig bison flex autoconf binutils-devel libevent-devel acl libfmt-devel libiberty-devel double-conversion-devel lz4-devel xz\
-devel openssl11-devel openssl11-static openssl11 libunwind-devel libdwarf-devel elfutils-libelf-devel glog-devel libffi-devel gdbm-devel libyaml-devel ncurses-devel readline-devel rh-ruby30 utfcpp unzip wget

ENV OPENSSL_ROOT_DIR=/usr/include/openssl11

# Set environment variables for rh-ruby30 to be default ruby
RUN echo "source /opt/rh/rh-ruby30/enable" >> /etc/profile.d/rh-ruby30

# places to drop things we have to build from source
RUN mkdir -p /missing/dist /missing/src

# missing things we have to build from source
ADD https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2 /missing/dist/jemalloc.tar.bz2
RUN tar xjf /missing/dist/jemalloc.tar.bz2 -C /missing/src && \
    source /opt/rh/devtoolset-11/enable && \
    cd /missing/src/jemalloc* && \
    ./configure && \
    make && \
    make install && \
    cd / && rm -rf /missing/src/jemalloc*

ADD https://github.com/fmtlib/fmt/releases/download/11.1.4/fmt-11.1.4.zip /missing/dist/fmt.zip
RUN unzip /missing/dist/fmt.zip -d /missing/src && \
    source /opt/rh/devtoolset-11/enable && \
    cd /missing/src/fmt* && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && \
    cmake --build . --config Release --target install && \
    cd / && rm -rf /missing/src/fmt*

ADD https://github.com/google/double-conversion/archive/refs/tags/v3.3.1.zip /missing/dist/dc.zip
RUN unzip /missing/dist/dc.zip -d /missing/src && \
    source /opt/rh/devtoolset-11/enable && \
    cd /missing/src/double-conversion-* && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && \
    cmake --build . --config Release --target install && \
    cd / && rm -rf /missing/src/double-conversion-*

ADD https://github.com/google/brotli/archive/refs/tags/v1.1.0.zip /missing/dist/brotli.zip
RUN unzip /missing/dist/brotli.zip -d /missing/src/ && \
    source /opt/rh/devtoolset-11/enable && \
    cd /missing/src/brotli-* && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && \
    cmake --build . --config Release --target install && \
    cd / && rm -rf /missing/src/brotli-*

ADD https://github.com/gflags/gflags/archive/refs/tags/v2.2.2.zip /missing/dist/gflags.zip
RUN unzip /missing/dist/gflags.zip -d /missing/src/ && \
    source /opt/rh/devtoolset-11/enable && \
    cd /missing/src/gflags-* && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && \
    cmake --build . --config Release --target install && \
    cd / && rm -rf /missing/src/gflags-*


ADD https://github.com/google/glog/archive/refs/tags/v0.7.1.zip /missing/dist/glog.zip
RUN unzip /missing/dist/glog.zip -d /missing/src/ && \
    source /opt/rh/devtoolset-11/enable && \
    cd /missing/src/glog-* && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && \
    cmake --build . --config Release --target install && \
    cd / && rm -rf /missing/src/glog-*

ADD https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.bz2 /missing/dist/boost.tar.bz2
RUN tar xjf /missing/dist/boost.tar.bz2 -C /missing/src && \
    cd /missing/src/boost-* && \
    ./bootstrap.sh && \
    ./b2 install && \
    cd / && rm -rf /missing/src/boost-*

# Clone the utfcpp repository and copy headers to the include path
RUN git clone https://github.com/nemtrif/utfcpp.git /usr/local/src/utfcpp && \
    mkdir -p /usr/local/include/utfcpp && \
    cp -r /usr/local/src/utfcpp/source/* /usr/local/include/utfcpp/

# Optional: Clean up unnecessary files
RUN rm -rf /usr/local/src/utfcpp && \
    yum clean all

ENV TZ=Etc/UTC
ARG ARCH=x64

ENV CC=/opt/rh/devtoolset-11/root/usr/bin/gcc
ENV CXX=/opt/rh/devtoolset-11/root/usr/bin/g++

COPY tools /opt/tools

RUN /opt/tools/tools.sh install_ruby

ENV TEBAKO_PREFIX=/root/.tebako
COPY test /root/test

RUN gem install tebako
#RUN tebako setup -R 3.3.7
#RUN tebako setup -R 3.4.1
#RUN tebako press -R 3.3.7 -r /root/test -e tebako-test-run.rb -o ruby-3.3.7-package
#RUN tebako press -R 3.4.1 -r /root/test -e tebako-test-run.rb -o ruby-3.4.1-package
# rm ruby-*-package

