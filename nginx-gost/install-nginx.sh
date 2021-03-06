#!/bin/bash -x

# Настройка необходимых пакетов
# ----------------------------------

# Пакеты будут скачены с "$url"
url="https://update.cryptopro.ru/support/nginx-gost"
certname='srvtest'
revision_openssl="164682"
pcre_ver="pcre-8.41"
zlib_ver="zlib-1.2.11"
csp=/usr/local/src/linux-amd64R3.tgz
# Версия nginx для загрузки с github
nginx_branch="stable-1.12"
no_exec=false

#if [ -n "$1" ] 
#then
#    if [ "$1" == "command_list" ]
#    then
#        no_exec=true
#    fi
#    csp=$1
#else
#    printf "No argument (CSP)"
#    exit 0
#fi

cat /etc/*release* | grep -Ei "(centos|red hat)"
if [ "$?" -eq 0 ] 
then
    apt="yum -y"
    pkgmsys="rpm"
    pkglist="rpm -qa"
    install="rpm -i"
    openssl_packages=(cprocsp-cpopenssl-110-base-4.0.0-5.noarch.rpm \
    cprocsp-cpopenssl-110-64-4.0.0-5.x86_64.rpm \
    cprocsp-cpopenssl-110-devel-4.0.0-5.noarch.rpm \
    cprocsp-cpopenssl-110-gost-64-4.0.0-5.x86_64.rpm)

    modules_path=/usr/lib64/nginx/modules
    cc_ld_opt=" --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie'" 

else
    cat /etc/*release* | grep -Ei "(ubuntu|debian)"
    if [ "$?" -eq 0 ] 
    then
        apt="apt-get"
        pkgmsys="deb"
        pkglist="dpkg-query --list"
        install="dpkg -i"
        openssl_packages=(cprocsp-cpopenssl-110-base_4.0.0-5_all.deb \
        cprocsp-cpopenssl-110-64_4.0.0-5_amd64.deb \
        cprocsp-cpopenssl-110-devel_4.0.0-5_all.deb \
        cprocsp-cpopenssl-110-gost-64_4.0.0-5_amd64.deb)

        modules_path=/usr/lib/nginx/modules
        cc_ld_opt=" --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'"
    else
        printf "Not supported system (supported: Ubuntu, CentOS, Red Hat)."
        exit 0
    fi
fi

prefix=/etc/nginx
sbin_path=/usr/sbin/nginx
conf_path=/etc/nginx/nginx.conf
err_log_path=/var/log/nginx/error.log
http_log_path=/var/log/nginx/access.log
pid_path=/var/run/nginx.pid
lock_path=/var/run/nginx.lock
http_client_body_temp_path=/var/cache/nginx/client_temp
http_proxy_temp_path=/var/cache/nginx/proxy_temp
http_fastcgi_temp_path=/var/cache/nginx/fastcgi_temp
http_uwsgi_temp_path=/var/cache/nginx/uwsgi_temp
http_scgi_temp_path=/var/cache/nginx/scgi_temp
user=root
group=nginx


# ----------------------------------

# Настройка установочной конфигурации nginx
# ----------------------------------


nginx_paths=" --prefix=${prefix} --sbin-path=${sbin_path} --modules-path=${modules_path} --conf-path=${conf_path} --error-log-path=${err_log_path} --http-log-path=${http_log_path} --http-client-body-temp-path=${http_client_body_temp_path} --http-proxy-temp-path=${http_proxy_temp_path} --http-fastcgi-temp-path=${http_fastcgi_temp_path} --http-uwsgi-temp-path=${http_uwsgi_temp_path} --http-scgi-temp-path=${http_scgi_temp_path} --pid-path=${pid_path} --lock-path=${lock_path}"

nginx_parametrs=" --user=${user} --group=${group} --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module"


# Возможны и другие модули для которых требуется самостоятельная установка пакетов, например:
# --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic
# --with-http_perl_module=dynamic

# ----------------------------------


# Загрузка, распаковка и установка пакетов
# ----------------------------------
if [ $no_exec == true ]
then
# Вывод комманд
# ----------------------------------
    echo "This commands will be carry out:" > command_list

    eval "$pkglist | grep -qw gcc"
    if ! [ "$?" -eq 0 ]
    then
        echo "$apt install gcc" >> command_list
    fi
    eval "$pkglist | grep \" git \""
    if ! [ "$?" -eq 0 ]
    then
        echo "$apt install git" >> command_list
    fi

    echo "wget --no-check-certificate -O nginx_conf.patch https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx_conf.patch" >> command_list
    echo "wget --no-check-certificate -O ${pcre_ver}.tar.gz ${url}/src/${pcre_ver}.tar.gz && wget --no-check-certificate -O ${zlib_ver}.tar.gz ${url}/src/${zlib_ver}.tar.gz" >> command_list
    for i in ${openssl_packages[@]}; do echo "wget --no-check-certificate -O $i ${url}/bin/${revision_openssl}/$i" >> command_list; done

    echo "tar -xzvf ${pcre_ver}.tar.gz && tar -xzvf ${zlib_ver}.tar.gz" >> command_list
    cmd=$install" lsb-cprocsp-kc2*"${pkgmsys}
    if ! [ -d "$csp" ]
    then
        if ! [ -d csp ]
        then
            echo "mkdir csp" >> command_list
        fi
        echo "tar -xzvf $csp -C csp --strip-components 1" >> command_list
        csp="csp"
    fi

    echo "cd ${csp} && ./install.sh && eval $cmd && cd .." >> command_list
    echo "cd ${pcre_ver} && ./configure && make && make install && cd .." >> command_list
    echo "cd ${zlib_ver} && ./configure && make && make install && cd .." >> command_list
    for i in ${openssl_packages[@]}; do
        cmd=$install" "$i
        echo "$cmd" >> command_list
    done

    echo "git clone https://github.com/nginx/nginx.git" >> command_list
    echo "cd nginx" >> command_list
    echo "git checkout branches/$nginx_branch" >> command_list
    echo "cd .. && git apply nginx_conf.patch" >> command_list
    echo "cd nginx" >> command_list
    cmd="./auto/configure${nginx_paths}${nginx_parametrs}${cc_ld_opt}"
    echo "$cmd && make && make install" >> command_list
    if ! [ -d /var/cache/nginx ]
    then
        echo "mkdir /var/cache/nginx" >> command_list
    fi

else
# ----------------------------------
    eval "$pkglist | grep -qw gcc"
    if ! [ "$?" -eq 0 ]
    then
        eval "$apt install gcc" || exit 1
    fi
    eval "$pkglist | grep \" git \""
    if ! [ "$?" -eq 0 ]
    then
        eval "$apt install git" || exit 1
    fi

    wget --no-check-certificate -O nginx_conf.patch https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx_conf.patch || exit 1
    wget --no-check-certificate -O ${pcre_ver}.tar.gz ${url}/src/${pcre_ver}.tar.gz && wget --no-check-certificate -O ${zlib_ver}.tar.gz ${url}/src/${zlib_ver}.tar.gz || exit 1

    for i in ${openssl_packages[@]}; do wget --no-check-certificate -O $i ${url}/bin/"${revision_openssl}"/$i || exit 1; done
    tar -xzvf ${pcre_ver}.tar.gz && tar -xzvf ${zlib_ver}.tar.gz || exit 1
    if ! [ -d "$csp" ]
    then
        if ! [ -d csp ]
        then
            mkdir csp
        fi
        tar -xzvf $csp -C csp --strip-components 1 || exit 1
        csp="csp"
    fi

    cmd=$install" lsb-cprocsp-kc2*"${pkgmsys}
    cd ${csp} && ./install.sh && eval "$cmd" && cd .. || exit 1
    cd ${pcre_ver} && ./configure && make && make install && cd .. || exit 1
    cd ${zlib_ver} && ./configure && make && make install && cd .. || exit 1
    for i in ${openssl_packages[@]}; do
        cmd=$install" "$i
        eval "$cmd" || exit 1
    done

    # ----------------------------------

    # Установка nginx
    # ----------------------------------

    git clone https://github.com/nginx/nginx.git
    cd nginx || exit 1
    git checkout branches/$nginx_branch || exit 1
    cd .. && git apply nginx_conf.patch || exit 1
    cd nginx
    cmd="./auto/configure${nginx_paths}${nginx_parametrs}${cc_ld_opt}"
    eval $cmd && make && make install || exit 1

    if ! [ -d /var/cache/nginx ]
    then
        mkdir /var/cache/nginx
    fi
fi

wget http://dorogov.us.to/srvtest.tar.gz -O /usr/local/src/srvtest.tar.gz
tar -xzf /usr/local/src/srvtest.tar.gz -C /


# Смена KC1 на KC2 в имени провайдера, так как nginx работает с провайдером KC2:
/opt/cprocsp/bin/amd64/certmgr -inst -store uMy -cont '\\.\HDIMAGE\srvtest' -provtype 75 -provname "Crypto-Pro GOST R 34.10-2001 KC2 CSP" || exit 1
#wget http://dorogov.us.to/srvtest.cer -O /usr/local/src/srvtest.cer
#/opt/cprocsp/bin/amd64/certmgr -inst -store umy -file /usr/local/src/srvtest.cer
#/opt/cprocsp/bin/amd64/certmgr -list -store umy


# Экспорт сертификата:
/opt/cprocsp/bin/amd64/certmgr -export -cert -dn "CN=${certname}" -dest "/etc/nginx/${certname}.cer" || exit 1

# Смена кодировкии сертификата DER на PEM:
openssl x509 -inform DER -in "/etc/nginx/${certname}.cer" -out "/etc/nginx/${certname}.pem" || exit 1

# Генерация сертификатов RSA:
openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/${certname}RSA.key -nodes -out /etc/nginx/srvtestRSA.pem -subj '/CN=${certname}RSA/C=RU' || exit 1
openssl rsa -in /etc/nginx/srvtestRSA.key -out /etc/nginx/${certname}RSA.key

# Загрузка файла конфигурации:
wget --no-check-certificate "https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx.conf" || exit 1

# Установка конфигурации nginx:
sed -r "s/srvtest/${certname}/g" nginx.conf > nginx_tmp.conf
rm nginx.conf
mv ./nginx_tmp.conf /etc/nginx/nginx.conf || exit 1
# ----------------------------------
