#!/bin/bash
package=$1
ver=$2
force=$3

function get_last_ver_python {
    if [[ "$1" == '' ]]; then
        k='^[34]'
        all="$(curl -L https://www.python.org/ftp/python/$1 2>/dev/null| sed -n "/<a href=/ s/<a href=[^>]*>\([^<]*\)<.*/\1/p"| grep $k| grep -v "${k}a"| grep -v "<h1>"|sort --version-sort | tail -n 10| tac)"
        for i in $all; do get_last_ver_python ${i%/}; done | sed 's/^[^34]*\([0-9.]*\)\..*/\1/'| uniq| tail -n 1
    else
        k="$1"
        all2="$(curl -L https://www.python.org/ftp/python/$1 2>/dev/null| sed -n "/<a href=/ s/<a href=[^>]*>\([^<]*\)<.*/\1/p"| grep $k| grep -v "${k}a"| grep -v "<h1>"| grep tgz| grep -v "${1}[abr]")"
        echo "$all2"
    fi
}

case "$package" in
    openssl)
        dnf install -y tk-devel
        tmp_dir=/tmp/make_openssl
        mkdir -p "$tmp_dir"
        pushd $tmp_dir 2>/dev/null
        wget -q https://www.openssl.org/source/openssl-${ver}.tar.gz.sha1
        sha1="$(cat openssl-${ver}.tar.gz.sha1)"
        if [[ "${sha1:0:6}" == "7d041c" && "$force" != "force" ]]; then
            echo "Для данной версии исходников пакет уже был собран."
            popd 2>/dev/null
            exit 0
        fi
        wget -q https://www.openssl.org/source/openssl-${ver}.tar.gz
        wget -q https://www.openssl.org/source/openssl-${ver}.tar.gz.asc
        gpg --verify openssl-${ver}.tar.gz.asc openssl-${ver}.tar.gz
        if [ $? -ne 0 ]; then
            echo "Подпись исходников не совпала. Выход."
            popd 2>/dev/null
            exit 1
        fi
        tar xzf openssl-${ver}.tar.gz
        unset CPPFLAGS LD_RUN_PATH LDFLAGS CFLAGS
        export LDFLAGS="-static-libgcc -static-libstdc++ -static"
        cd openssl-${ver}
        ./config --prefix=/opt/public/openssl-static --openssldir=/usr/local/ssl enable-threads no-shared no-module -fPIC -march=native
        make depend
        make
        make install
        cd ..
        tar czf openssl-${ver}{.tgz,}
        popd 2>/dev/null
        ;;
    python)
        dnf install -y tk-devel
        openssl_bin=/opt/public/openssl-static/bin/openssl
        if [ ! -f $openssl_bin ]; then
            make.sh openssl 3.6.0
        fi
        [[ "$ver" == "last" ]] && ver="$(get_last_ver_python '')"
        tmp_dir=/tmp/make_python
        mkdir -p "$tmp_dir"
        pushd $tmp_dir 2>/dev/null
        wget -q https://www.python.org/ftp/python/$ver/Python-$ver.tgz.sig
        sha1="$(sha1sum Python-$ver.tgz.sig)"
        if [[ "${sha1:0:6}" == "091423" && "$force" != "force" ]]; then
            echo "Для данной версии исходников пакет уже был собран."
            popd 2>/dev/null
            exit 0
        fi
        echo "Скачивание исходников."
        wget -q https://www.python.org/ftp/python/$ver/Python-$ver.tgz
        wget -q https://www.python.org/ftp/python/$ver/Python-$ver.tgz.crt
        echo "Проверка подписи."
        cosign verify-blob --signature Python-$ver.tgz.sig --certificate Python-$ver.tgz.crt --certificate-identity "hugo@python.org" --certificate-oidc-issuer "https://github.com/login/oauth" Python-$ver.tgz
        if [ $? -ne 0 ]; then
            echo "Подпись исходников не совпала. Выход."
            popd 2>/dev/null
            exit 1
        fi
        tar xzf Python-$ver.tgz
        cd Python-$ver
        unset CPPFLAGS LD_RUN_PATH LDFLAGS CFLAGS
        export OPENSSL_STATIC_DIR=/opt/public/openssl-static
        export CFLAGS="-O3 -march=native -fPIC"
        export CPPFLAGS="-I$OPENSSL_STATIC_DIR/include -DOPENSSL_THREADS"
        export LD_RUN_PATH="$OPENSSL_STATIC_DIR/lib64"
        #ENV LDFLAGS="-L$OPENSSL_STATIC_DIR/lib64 -lssl -lcrypto -ldl -lpthread -static-libgcc -static-libstdc++ -static"
        export LDFLAGS="-L$OPENSSL_STATIC_DIR/lib64 -lssl -lcrypto -ldl -lpthread"
        #export LINKFORSHARED=" " 
        #export CCSHARED="" 
        #export LDSHARED="" 
        #export LDCXXSHARED=""
        ./configure --prefix=/opt/public/portable-python-3.14.0 --enable-optimizations --with-openssl=$OPENSSL_STATIC_DIR --with-ensurepip=install --disable-shared --with-static-libpython
        make
        make install
        ;;
    x11)
        sudo dnf install -y audit-libs-devel gettext-devel libcap-ng-devel libuser-devel libutempter-devel pam-devel  popt-devel rubygem-asciidoctor systemd-devel xcb-proto python3-devel> /dev/null 2>&1
        need_libs=("libXau.a" "libX11.a" "libXext.a" "libXmu.a" "libXmuu.a" "libxcb.a" "libXdmcp.a" "libuuid.a" "libblkid.a" "libmount.a" "libfdisk.a" "libsmartcols.a")
        packages="libXau libX11 libXext libXmu libxcb libXdmcp util-linux"
        #need_libs=("libuuid.a" "libblkid.a" "libmount.a" "libfdisk.a" "libsmartcols.a")
        #packages="util-linux"
        
        # Устанавливаем рабочую директорию, куда DNF скачивает исходники по умолчанию
        SRC_RPM_DIR=~/rpmbuild/SRPMS
        SPEC_DIR=~/rpmbuild/SPECS
        [ -e $SRC_RPM_DIR ] || mkdir -p $SRC_RPM_DIR
        [ -e $SPEC_DIR ] || mkdir -p $SPEC_DIR

        echo 'Скачивание исходников'
        for package_ in $packages; do
            RPM_FILE=$(find "$SRC_RPM_DIR" -name "${package_}-*.src.rpm" | head -n 1)
            if [ ! -f "$RPM_FILE" ]; then
                dnf download --source $package_ -q
            fi
            # Если накосячили с правкой spec, то повторный запуск востанавливает их.
            rpm -ivh "$SRC_RPM_DIR/${package_}-"*.src.rpm >/dev/null 2>&1 
        done

        pushd "$SPEC_DIR" > /dev/null
        
        for package_ in $packages; do
            SPEC_FILE="${package_}.spec"
            # БЛОК ВКЛЮЧЕНИЯ СТАТИЧЕСКОЙ СБОРКИ
            case "$package_" in
                libX11)
                    sed -i.bak 's/\(%configure --disable-silent-rules\)\( --disable-static\)/#\1\2\n\1/' $SPEC_FILE 
                    ;;
                *)
                    sed -i.bak 's/--disable-static/--enable-static/' $SPEC_FILE
                    ;;
            esac
            
            # удаляем удаление статических сборок
            sed -i '/rm -f.*\.a/d' "$SPEC_FILE"
            sed -i '/find .*-delete/d' "$SPEC_FILE"
            
            # БЛОК УПАКОВКИ СТАТИЧЕСКИХ БИБЛИОТЕК В RPM
            sed -i '/^%files.*devel/a%{_libdir}/lib*.a' $SPEC_FILE
        done
        
        
        echo 'Запуск тихой сборки всех пакетов X11...'
        export DEBUG_RPM_BUILD=1
        # Отключаем проверку неупакованных файлов, так как мы вручную добавляем статику
        export __os_install_post="/usr/lib/rpm/brp-compress" 
        # Или более агрессивно:
        export _unpackaged_files_terminate_build=0
        
        # Устанавливаем RPM опцию, которая активирует условную сборку статики внутри spec-файла util-linux
        # Эта переменная должна быть экспортирована ПЕРЕД вызовом rpmbuild
        export RPM_BUILD_OPTS="--with static_libuuid" 

        # Инициализируем массив для хранения результатов
        declare -A PIDS
        declare -a results

        for package_ in $packages; do
            # Запускаем сборку в фоновом режиме (&) внутри подоболочки
            # и полностью подавляем весь вывод на экран (перенаправляем в файл-лог)
            (rpmbuild -ba $package_.spec > ${package_}_build.log 2>&1) &
            # Запоминаем PID фонового процесса
            PIDS["$package_"]=$!
        done

        echo 'Ожидание завершения всех сборок...'
        
        # Ожидаем завершения всех фоновых процессов и собираем результаты
        for package_ in $packages; do
            wait ${PIDS["$package"]}
            if [ $? -eq 0 ]; then
                results+=("✅ $package_: Успешно (логи в ${package_}_build.log)")
            else
                results+=("❌ $package_: ОШИБКА (см. ${package_}_build.log для деталей)")
                # Запоминаем факт ошибки
                BUILD_FAILED=true
            fi
        done
        popd >/dev/null

        mkdir -p /opt/public/x11_static
        echo 'Перемещение в /opt/public/x11_static/'
        # mv ~/rpmbuild/RPMS/x86_64/* /opt/public/x11_static/
        # Используем find и xargs, чтобы избежать ошибок "слишком длинный список аргументов", если RPM-ок много
        find ~/rpmbuild/RPMS/x86_64/ -maxdepth 1 -name "*.rpm" -exec mv {} /opt/public/x11_static/ \;
        
        # Выводим сводный отчет в конце
        echo "--- СВОДНЫЙ ОТЧЕТ СБОРКИ X11 ---"
        for result in "${results[@]}"; do
            echo "$result"
        done
        echo "---------------------------------"

        if [ "$BUILD_FAILED" = true ]; then
            echo "Одна или несколько сборок завершились неудачно. Проверьте логи. Краткая сводка:"
            grep -A6 -P '(?<!-W)error' ~/rpmbuild/SPECS/*_build.log
            exit 1
        fi
        
        echo "Проверка наличия .a файлов внутри собранных RPM-пакетов:"
        exist_libs=$(rpm -qpl /opt/public/x11_static/*.x86_64.rpm | grep '\.a'| sed 's|/usr/lib64/||')
        missing_libs=$(comm -23 <(printf "%s\n" "${need_libs[@]}" | sort) <(printf "%s\n" $exist_libs | sort))
        if [[ -z "$missing_libs" ]]; then
            echo "✅ Все необходимые библиотеки найдены в RPM-пакетах."
        else
            echo "❌ Не хватает следующих библиотек (только в need_libs, нет в exist_libs):"
            echo "$missing_libs"
        fi
        ;;
    xauth)
        # распаковка статически собранных библиотек
        export X11_STATIC_DIR=/app/x11_extracted
        export X11_RPM_DIR=/opt/public/x11_static
        export OPENSSL_STATIC_DIR=/opt/public/openssl-static
        export BUILD_DIR=/app/xauth-1.1.4
        
        # # Получаем все флаги X11/XCB через pkg-config
        # export X11_LIBS=$(pkg-config --static --libs xmu xext xau x11 xdmcp)
        # echo "X11_LIBS: $X11_LIBS" # Выводим для отладки

        LIBS_ORDER="-lXmu -lXext -lX11 -lxcb -lXau -lXdmcp -luuid -lssl -lcrypto -ldl -lpthread"
        
        
        echo -n "собранные пакеты со статическими библиотеками лежат в "
        echo "/opt/public/x11_static  ($(ls /opt/public/x11_static) файлов)." 
        rpm -qpl /opt/public/x11_static/*.x86_64.rpm | grep '\.a' > $BUILD_DIR/a_in_rpm.log
        echo -n "статически собранные библиотеки, которые в них присутствуют, "
        echo "можно посмотреть в  $BUILD_DIR/a_in_rpm.log ($(wc -l $BUILD_DIR/a_in_rpm.log))"
        

        # вытаскиваем *.a
        mkdir -p  $X11_STATIC_DIR
        cd $X11_STATIC_DIR
        for pac in $X11_RPM_DIR/*.rpm; do
            rpm2cpio $pac | cpio -idmv
        done > extract.log 2>&1
        cd /app

        # получение исходников
        if [ -f /opt/public/xauth-1.1.4.tar.gz ]; then
            cp /opt/public/xauth-1.1.4.tar.gz ./
        else
            wget https://www.x.org/releases/individual/app/xauth-1.1.4.tar.gz
        fi
        tar -zxf xauth-1.1.4.tar.gz 
        cd xauth-1.1.4/

        # NOTE: Здесь мы устанавливаем пути, когда файлы уже доступны в $X11_STATIC_DIR
        export CFLAGS="-O3 -march=native -I$OPENSSL_STATIC_DIR/include -I/usr/include -I$X11_STATIC_DIR/usr/include"
        export LDFLAGS_STATIC_PATHS="-L$OPENSSL_STATIC_DIR/lib64 -L$X11_STATIC_DIR/usr/lib64" 
        export PKG_CONFIG_PATH="$X11_STATIC_DIR/usr/lib64/pkgconfig:$OPENSSL_STATIC_DIR/lib64/pkgconfig:/usr/lib64/pkgconfig:$PKG_CONFIG_PATH"
        export LIBRARY_PATH="$X11_STATIC_DIR/usr/lib64:$OPENSSL_STATIC_DIR/lib64:/usr/lib64"


        ls /usr/lib64/libX*.a > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Вниманиме! Обнаружено присутствие предустановленных библиотек."
            echo " Они могут помешать сборке (подцепятся .so вместо .a)."
        fi
        # изначально предустановлены: make automake gcc pkgconfig wget git libuuid-devel
        # NOTE: Устанавливаем dev пакеты, чтобы удовлетворить зависимости configure/pkg-config системными .so файлами, 
        # но линковка будет использовать наши .a файлы из LIBRARY_PATH благодаря -static флагу и порядку линковки.
        (dnf install -y libXmu-devel libXext-devel libxcb-devel libuuid-devel >/dev/null 2>&1)

        ./configure --enable-static > configure.log 2>&1

        
        # *** РУЧНОЕ ИСПРАВЛЕНИЕ MAKEFILE ***
        # Находим строку с LIBS и принудительно меняем её порядок, 
        # перемещая библиотеки XCB/OpenSSL в конец списка.
        # ЭТО ОЧЕНЬ АГРЕССИВНЫЙ SED, ОН ЗАМЕНЯЕТ ВСЮ СТРОКУ LIBS:
        sed -i "s|^LIBS =.*|LIBS = $LIBS_ORDER|g" Makefile
        
        make V=1 LDFLAGS="-static $LDFLAGS_STATIC_PATHS"> make.log 2>&1
        
        if [ $? -eq 0 ]; then
            cp xauth /opt/public/
        else
            tail -n 15 make.log
        fi
        ;;
    *)
        echo "Пакет не распознан."
        exit 1
        ;;
esac
