# -*- coding: utf-8 -*-
require 'json'
require 'matrix'
require 'fileutils'

#-------------------------------------------class--------------------------------------------------
class Logkaiseki
  def initialize
    @key = 0 #代表点を格納するハッシュのキー
    @count = 1
    @posi_data = Array.new #position配列を格納
    @daihyo = {} # key=> "数字" value=> 代表点の配列
  end

  def return_data
    return @posi_data
  end

  def return_daihyo
    return @daihyo
  end
  
  def kaiseki(filename)
    txtfile = File.open(filename) #このファイル内に"試合状態が記録されたファイルのファイル名"が記録されている
    txtfile.each_line do |line|  #jxon.txtファイル中に記録されているファイル名を1行ずつ読み込む
      json_data = JSON.load(File.read(line.chomp)) #.chompは末尾の改行文字を削除した文字列を返す
      json_data.each do |datan|  #大元の繰り返し,JSONデータの配列すべてに関して
        data = datan
        show = data['show']
        time = show['time']
        ball = show['ball']
        left = show['left']
        right= show['right']
        position = Array.new #ボールの座標、左チームの各選手の座標、右チームの各選手の座標の順で配列に格納
                             #時間を配列の先頭に追加
        if time.to_i == @count then  
          #ボールの位置を格納
          position.push(ball[0].to_f)
          position.push(ball[1].to_f)
          #leftチームの位置を格納
          left.each do |l|
            position.push(l[1].to_f)
            position.push(l[2].to_f)
          end
          #rightチームの位置を格納
          right.each do |r|
            position.push(r[1].to_f)
            position.push(r[2].to_f)
          end
          v = Vector.elements(position,true)
          #time
          position.unshift(time.to_i)
          
          @posi_data.push(position.dup) #データ点にposition配列をベクトル化したものを追加
          if @count % 500 == 0 then
             @daihyo[@key.to_s] = v
            @key += 1 #キーの値をインクリメント 
          end
          position.clear #配列を空にする
          @count +=1
          #3000ステップ目はカウントされないみたいなので、countが3000になった時の場合を考える
          if @count == 3000 then
            @count = 3001
          end
        end # if_end
          #--ここから 19 行はうえのコピーなので、if time.to_i == @count ... と if @count == 3000 という @count の操作だけ取り出して別にして書き直せる。
          #-- うまく書くとここまでの 19 行は削除できる。
        
      end #each_end
    end #each.line_end
    txtfile.close
  end #kaiseki_end
  
end #class_end

class LVQ
  ALPHA1 = 0.01  #代表点を近づけるときに使う定数
  ALPHA2 = ALPHA1 * 0.01 #代表点を遠ざけるときに使う定数α(0<α<1) # ALPHA1 に対する相対値で表示 (1/100)
  def initialize(amb,data) #代表ベクトル、データベクトルを初期値として受け取る
    count = 1
    file = File.open("pre.txt","w+")
    @group_nagare = {} #試合状態の流れが同一グループにいくつ存在するか記録しておくハッシュ
    #key => "ラベル" value => (試合状態の流れの数)
    @group_mitudo = {} #グループに属す全てのテスト点から代表点までの距離の和を記録しておく（最終的に平均を取る）
    @daihyo = amb #ハッシュ
    @data = data  #配列
    @result = Hash.new{|h,key| h[key]=[]}#ラベル付けしたデータ点を記録
    @daihyo.each{ |key,value|
      file.puts"key=>#{key} value=> #{value}\n\n"
    }
    file.close
  end


  #LVQ1により代表点の更新を行う
  def lvq

    #すべてのデータ点について
    @data.each  do |d|
      v_min = Float::MAX         #距離の最小値を保存
      min = "0"                     #最も近い代表点のキーを保存
      d2 = d.dup
      d2.shift
      v = Vector.elements(d2,true)
      @daihyo.each{ |key,value|     #代表点との距離を計算
        tmp_v = v-value
        if tmp_v.r < v_min then
          min = key                 #最小値のキーをminに記録
          v_min = tmp_v.r           #距離の最小値を更新
        end
      }
      
      @daihyo.each{ |key,value|     #代表点の値を更新
        tmp_v = v - value
        if key == min then           #一番近い代表点はそのデータ点に近づける
          @daihyo[key] = value + tmp_v.*(ALPHA1)
        else                        #それ以外の代表点はそのデータ点から遠ざける
          @daihyo[key] = value - tmp_v.*(ALPHA2)
        end
      }
      
    end
    
  end #lvq_end

  def daihyo_output #代表ベクトルの最終的な値をファイルに出力
    #データ点にラベル付けし、resultハッシュに追加
    #すべてのデータ点について



    @data.each  do |d|
      v_min = Float::MAX         #距離の最小値を保存
      min = "0"                     #最も近い代表点のキーを保存
      d2 = d.dup                    #配列の中身だけコピー
      d2.shift                      #ベクトル計算のために先頭の時間を配列から取り出す
      v = Vector.elements(d2,true)  #先頭に記録されていた時間を取り除いた配列をベクトル化
      @daihyo.each{ |key,value|     #代表点との距離を計算
        tmp_v = v-value             #データ点と代表点との差を計算　
        if tmp_v.r < v_min then     #差の距離（ノルム）を計算し、それが記録されていた最小値より小さい時
          min = key                 #最小値のキーをminに記録
          v_min = tmp_v.r           #距離の最小値を更新
        end
      }     
      #データ点にラベル付を行う
      @result[min] << d
      #グループの全てのテスト点から代表点までの距離の和を記録しておく
      if !(@group_mitudo.has_key?(min)) then #まだキーminが登録されていない時
        @group_mitudo[min] = v_min
      else                                  #登録されている時
        @group_mitudo[min] += v_min
      end

      #グループの流れを記録するハッシュを初期化しておく
      if !(@group_nagare.has_key?(min)) then #hashがkeyとしてminを持っていなければ
        @group_nagare[min] = 1               #key=>minに試合の流れの数を1で初期化して代入
      end
    end
 
    count=1
    file = File.open("result.txt","w+")
    @daihyo.each{ |key,value|
      file.puts"key=>#{key} value=>#{value}\n\n"  
    }
    file.close
  end #output_end

  def rabel_output #ラベル付けしたデータをtxtファイルに出力
    FileUtils.rm_r("result") #中身があっても強制的に削除    
    Dir.mkdir("result")    #resultというディレクトリを作成
    Dir.chdir("result") {  #作成したディレクトリに移動し実行
      #ラベル付けされたデータをグループごとにファイル出力
      @result.each{ |key,value|
        file = File.open("#{key}.txt","w+") 
        rcg_file = File.open("#{key}.rcg","w+")
        mitudo = @group_mitudo[key]/@result[key].size
        puts "#{key}:テスト点の数,#{@result[key].size}個　平均距離,#{mitudo}\n"
        t1 = value[0][0] #今のデータの時間を記録
        value.each do |a|
          t2 = a[0]      #次のデータの時間を記録
          if (t2-t1) > 1 then #時間の流れが途切れたら区切りを入れる
            @group_nagare[key] += 1 #試合状態の流れの数をインクリメント
            file.puts("\n")
            t1 = t2
            end
          t1 = t2
          file.puts("#{a}\n")
        end
        file.close
      }
    }
    p @group_nagare
  end #rabel_output end

  def rcg_convert(arr,rcg) #配列とファイル名を受け取り、rcg形式でデータを出力
  end

  #代表ベクトルを表示
  def print
    p @daihyo
  end

end  #class_end

#------------------------------------main-----------------------------------------
def main
  
  data = Array.new
  daihyo = {}
  
  game = Logkaiseki.new
  game.kaiseki("json.txt")
  data = game.return_data
  daihyo = game.return_daihyo
  
  lvq = LVQ.new(daihyo,data)
  2.times do #LVQをn回行う
    lvq.lvq
  end
  lvq.daihyo_output
  lvq.rabel_output
end

main
