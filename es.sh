#!/usr/bin/bash
#author Ten.J
systemctl stop firewalld &> /dev/null
setenforce 0 &> /dev/null

qjpath=`pwd`

#ELK所需用到的所有tar包
#java_tar='jdk-8u211-linux-x64.tar.gz'
es_tar='elasticsearch-6.5.4.tar.xz'
es_head='elasticsearch-head-master.zip'
es_node='node-v4.4.7-linux-x64.tar.gz'
es_phantomjs='phantomjs-2.1.1-linux-x86_64.tar.bz2'

#if [ ! -e $qjpath/$java_tar ]
#then
#	echo 'jdk包不存在，请先上传'
#	exit
#fi

if [ ! -e $qjpath/$es_tar ]
then
	echo 'elasticsearch包不存在，请先上传'
	exit
fi

if [ ! -e $qjpath/$es_head ]
then
	echo 'head插件包不存在，请先上传'
	exit
fi

if [ ! -e $qjpath/$es_node ]
then
	echo 'node插件包不存在，请先上传'
	exit
fi

if [ ! -e $qjpath/$es_phantomjs ]
then
	echo 'phantomjs插件包不存在，请先上传'
	exit
fi

#部署java环境，java包没有的情况下用yum直接装吧
#echo '开始部署java环境。。。'
#tar xf $qjpath/$java_tar -C /usr/local/
#mv /usr/local/jdk1.8.0_211 /usr/local/java
#echo 'JAVA_HOME=/usr/local/java' >> /etc/profile.d/java.sh
#echo 'PATH=$PATH:$JAVA_HOME/bin' >> /etc/profile.d/java.sh
#echo 'export JAVA_HOME PATH' >> /etc/profile.d/java.sh
#source /etc/profile.d/java.sh
yum -y install java

#配置es
echo '开始配置es。。。'
tar xf $qjpath/$es_tar -C /usr/local/ 
mv /usr/local/elasticsearch-6.5.4 /usr/local/elasticsearch

useradd es
echo '123456' | passwd --stdin 'es'

#es节点配置
es_num=1
es_node1="'192.168.0.109'"
es_node2="'192.168.0.106'"
es_master=true
es_data=true

echo "
cluster.name: my-elk
node.name: elk-${es_num}
node.master: ${es_master}
node.data: ${es_data}
path.data: /data/elasticsearch/data
path.logs: /data/elasticsearch/logs
bootstrap.memory_lock: false
bootstrap.system_call_filter: false
network.host: 0.0.0.0
http.port: 9200
#discovery.zen.ping.unicast.hosts: [${es_node1}, ${es_node2}]
#discovery.zen.minimum_master_nodes: 2
#discovery.zen.ping_timeout: 150s
#discovery.zen.fd.ping_retries: 10
#client.transport.ping_timeout: 60s
http.cors.enabled: true
http.cors.allow-origin: '*'

" > /usr/local/elasticsearch/config/elasticsearch.yml

mkdir /data/elasticsearch/data -p
mkdir /data/elasticsearch/logs -p

chown es.es -R /data/elasticsearch
chown es.es -R /usr/local/elasticsearch

#设置JVM堆大小
sed -i 's/-Xms1g/-Xms4g/' /usr/local/elasticsearch/config/jvm.options
sed -i 's/-Xmx1g/-Xmx4g/' /usr/local/elasticsearch/config/jvm.options

#设置系统参数
echo '正在配置系统参数。。。'

echo '
* soft nofile 65536
* hard nofile 131072
* soft nproc 2048
* hard nproc 4096
* hard nofile 65536
' >> /etc/security/limits.conf

echo '
vm.swappiness=0
vm.max_map_count=262144
' >> /etc/sysctl.conf

sysctl –p
sysctl -w vm.max_map_count=262144

su - es -c "cd /usr/local/elasticsearch && nohup bin/elasticsearch &"

if [ $? -eq 0 ]
then 
	echo '配置es部分完成'
fi

#配置node插件
echo '开始配置head插件'
yum -y install unzip
tar xf $qjpath/$es_node -C /usr/local/
mv /usr/local/node-v4.4.7-linux-x64 /usr/local/node
echo '
NODE_HOME=/usr/local/node
PATH=$NODE_HOME/bin:$PATH
export NODE_HOME PATH
' >> /etc/profile.d/node.sh
source /etc/profile.d/node.sh
sleep 1
node --version
if [ $? -nq 0 ]
then 
	echo 'node插件配置失败'
	exit
fi

#解压head安装包
unzip  $qjpath/$es_node
mv elasticsearch-head-master /usr/local/elasticsearch-head-master

#安装grunt
cd /usr/local/elasticsearch-head-master
npm install -g grunt-cli
sleep 1
grunt –-version
if [ $? -nq 0 ]
then 
	echo 'grunt插件配置失败'
	exit
fi
rm -fr /usr/local/elasticsearch-head-master/Gruntfile.js
cp $qjpath/Gruntfile.js /usr/local/elasticsearch-head-master/

#安装phantomjs
yum -y install bzip2
cd $qjpath
tar xf $qjpath/$es_phantomjs -C /usr/local/
ln /usr/local/bin/phantomjs /usr/bin/phantomjs

#运行head
cd /usr/local/elasticsearch-head-master/
npm install
if [ $? -nq 0 ]
then 
	echo 'head插件配置失败'
	exit
fi

nohup grunt server &
ipaddr=`ip a | grep inet|grep brd|awk '{print $2}'|awk -F/ '{print $1}'` #获取当前ip
echo "配置完成，访问http://${ipaddr}:9100"




