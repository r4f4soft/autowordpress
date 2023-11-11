#!/bin/bash

# Colores
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
yellowColour="\e[0;33m\033[1m"
greenColour="\e[0;32m\033[1m"
blueColour="\e[0;34m\033[1m"
whiteColour="\e[1;37m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -e "\n${redColour}[!] Saliendo...\n${endColour}"
	tput cnorm; exit 1
}

# Comprobamos si es usuario root el que está ejecutando el script
if [ $(id -u) -ne 0 ];then
	echo -e "${redColour}Debes ejecutar el script con sudo (sudo $0)${endColour}"
	exit 0
fi

echo ""
echo "▄▀█ █░█ ▀█▀ █▀█ █░█░█ █▀█ █▀█ █▀▄ █▀█ █▀█ █▀▀ █▀ █▀"
echo "█▀█ █▄█ ░█░ █▄█ ▀▄▀▄▀ █▄█ █▀▄ █▄▀ █▀▀ █▀▄ ██▄ ▄█ ▄█"
echo ""
echo -e "by r4f4soft\n"

tput civis
# Actualizar repositorios
apt update &>/dev/null
# Instalación de dependencias
function instalar_dependencias(){
	dependencias=(apache2 mariadb-server php wget sed php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-mysql libapache2-mod-php)

	echo -e "${greenColour}Instalando paquetes necesarios...${endColour}"

	
	for programa in "${dependencias[@]}";do
		apt install $programa -y &>/dev/null
		echo -e "${yellowColour}[+]${endColour} - ${whiteColour}$programa${endColour} ${greenColour}Instalado${endColour}"
	done; tput cnorm
}

instalar_dependencias

cd /var/www/

# Eliminar archivos existentes de Wordpress
if [ -e /var/www/wordpress ];then
	rm -rf /var/www/wordpress
fi


if [ -e /var/www/latest.tar.gz ];then
	rm -rf /var/www/latest.tar.gz
fi

# Bajada del latest de Wordpress y descompresión
wget -q https://wordpress.org/latest.tar.gz && tar -zxvf latest.tar.gz &>/dev/null
rm -rf /var/www/latest.tar.gz

# Introducción de nombre de base de datos y credenciales de MySQL
echo -ne "${whiteColour}\nIngrese el nombre de la base de datos: ${endColour}" && read databasename
echo -ne "${whiteColour}Ingrese un usuario para la base de datos: ${endColour}" && read username
echo -ne "${whiteColour}Ingrese la contraseña para el usuario: ${endColour}" && read -s password
echo ""

# Configuración archivo wp-config.php
ficheroconfig="/var/www/wordpress/wp-config.php"
cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
chown -R www-data:www-data /var/www/wordpress/
sed -i "s/database_name_here/$databasename/" $ficheroconfig
sed -i "s/username_here/$username/" $ficheroconfig
sed -i "s/password_here/$password/" $ficheroconfig

# Configuración apache2
cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>

	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/wordpress

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	<Directory /var/www/wordpress>
		Options Indexes FollowSymLinks
		AllowOverride All
		Require all granted
	</Directory>

	<IfModule mod_dir.c>
		DirectoryIndex index.php
	</IfModule>

</VirtualHost>
EOF

# Habilitar sitio wordpress.conf
a2dissite 000-default &>/dev/null && a2ensite wordpress.conf &>/dev/null

# Configuración de MySQL
service mysql start &>/dev/null
mysql -u root -p" " -e "CREATE DATABASE IF NOT EXISTS $databasename; CREATE USER IF NOT EXISTS '$username'@'%' IDENTIFIED BY '$password'; GRANT ALL PRIVILEGES ON $databasename.* TO '$username'@'%'; FLUSH PRIVILEGES; " 2>/dev/null
service mysql restart &>/dev/null

# En caso de que el servicio no se llame mysql en el sistema
if [ $? -ne 0 ];then
	service mariadb start &>/dev/null
	mysql -u root -p" " -e "CREATE DATABASE IF NOT EXISTS $databasename; CREATE USER IF NOT EXISTS '$username'@'%' IDENTIFIED BY '$password'; GRANT ALL PRIVILEGES ON $databasename.* TO '$username'@'%'; FLUSH PRIVILEGES; " 2>/dev/null
	service mariadb restart &>/dev/null
fi

# Reinicio de los servicios
service apache2 restart &>/dev/null
