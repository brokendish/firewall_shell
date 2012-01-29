#!/bin/sh
#--------------------------------------------------------------------
#リアルタイムアクセス拒否β（Apacheログ専用）
#
#処理概要：
# ①Apacheのログファイルを（ほぼ）リアルタイムで監視して、拒否したいアクセスをしてきたIPアドレスを
# 「iptables」に登録して、全ての通信を拒否する。
# ②アクセス拒否IPを累積する
# ③アクセス拒否IP登録メールをroot宛に送信する
#
#注意：
# β版なので、期待しない。
# 「iptables」を使用しているのでその使い方は知っていたほうがいい。
#
#使用条件：
# ファイルの更新監視には「inotify」を使用しているので、inotifyがインストールされていること。
# Debian、Ubuntuの場合、「apt-get install inotify-tools」でインストール！
# ※カーネル2.6.13 以降
# 「iptables」を使用しているのでインストールされていること。
# カーネル2.6.13 以降であれば通常入ってると思う
#
#使用方法：
# 実行例１：バックグラウンドで実行
# ./inotifywait-apache2.sh &
#
#実行例２：フォアグラウンドで実行
# ./inotifywait-apache2.sh
#
#--------------------------------------------------------------------
#----------------------------------------
# 初期設定
#----------------------------------------
#Apacheログファイル
chkLogFile=/var/log/apache2/access.log
#アクセス拒否IP累積リスト
denyIpFile=/var/log/apache2/denyIP
#アクセス拒否判定文字列:エージェント「ZmEu」でアクセスしてきて「HTTP 404」出したヤツのIP取得
chkStr='.+GET.+HTTP/1\.1" 404.+"ZmEu"'
#----------------------------------------
touch $denyIpFile

while inotifywait -e modify $chkLogFile;
do
  #アクセス拒否判定文字列の検索(累積リストにあるものは対象外)
  cnt=`grep -f $denyIpFile -v $chkLogFile|egrep "$chkStr"|wc -l|cut -d " " -f 1`
  #引っかかった場合
  if [ "$cnt" != "0" ];
    then
      #作業リストとしてIPアドレスを保持する
      grep -f $denyIpFile -v $chkLogFile|egrep "$chkStr" |awk '{print $1}'|sort|uniq>$denyIpFile$$

      #累積リストと今回のリストを比較して新規をiptablesに登録
      for inIp in `comm -23 $denyIpFile$$ $denyIpFile`;
      do
         iptables -I INPUT -s $inIp -j DROP
      done

      #IPを標準出力に表示
      echo `date`
      cat $denyIpFile$$

      #累積リストに追加
      cat $denyIpFile>>$denyIpFile$$
      cat $denyIpFile$$|sort|uniq>$denyIpFile
      #メール通知
      cat $denyIpFile$$|mail -s "inotifywait-apache2 LOCK IP!!" "root"
      #作業リストを削除
      rm $denyIpFile$$
  else
      echo "Normal Access!!:"`date`
  fi
done
