# -*- coding: utf-8 -*-
require 'json'
require 'matrix'

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
  
  def kaiseki
    txtfile = File.open("json.txt") #このファイル内に"試合状態が記録されたファイルのファイル名"が記録されている
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
          @posi_data.push(v) #データ点にposition配列をベクトル化したものを追加
          if @count % 500 == 0 then
             @daihyo[@key.to_s] = v
            @key += 1 #キーの値をインクリメント 
          end
          position.clear #配列を空にする
          @count +=1
          #3000ステップ目はカウントされないみたいなので、countが3000になった時の場合を考える
        elsif @count == 3000 then
          @count = 3001
          #ball
          position.push(ball[0].to_f)
          position.push(ball[1].to_f)
          #left_team
          left.each do |l|
            position.push(l[1].to_f)
            position.push(l[2].to_f)
          end
          #right_team
          right.each do |r|
            position.push(r[1].to_f)
            position.push(r[2].to_f)
          end
          v = Vector.elements(position,true)
          @posi_data.push(v)
          position.clear
          @count += 1
        end #if_end
        
      end #each_end
    end #each.line_end
    txtfile.close
  end #kaiseki_end
end #class_end

class LVQ
  ALPHA1 = 0.01  #代表点を近づけるときに使う定数
  ALPHA2 = 0.0001 #代表点を遠ざけるときに使う定数α(0<α<1)
  def initialize(amb,data) #代表ベクトル、データベクトルを初期値として受け取る
    count = 1
    file = File.open("pre.txt","w+")
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
    @data.each  do |v|
      v_min = 99999999999.0         #距離の最小値を保存
      min = "0"                     #最も近い代表点のキーを保存

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
    
  end

  def daihyo_output #代表ベクトルの最終的な値をファイルに出力
                    #また、データ点のラベル付を行う
    res = Array.new
    #すべてのデータ点について
    @data.each  do |v|
      v_min = 99999999999.0         #距離の最小値を保存
      min = "0"                     #最も近い代表点のキーを保存
      @daihyo.each{ |key,value|     #代表点との距離を計算
        tmp_v = v-value             #データ点と代表点との差を計算　
        if tmp_v.r < v_min then     #差の距離（ノルム）を計算し、それが記録されていた最小値より小さい時
          min = key                 #最小値のキーをminに記録
          v_min = tmp_v.r           #距離の最小値を更新
        end
      }     
     #データ点にラベル付を行う
     res = v
     @result[min] << res 
    end

    @result.each{ |key,value|
      puts "#{key}:#{@result[key].size}個\n"
    }

    count=1
    file = File.open("result.txt","w+")
    @daihyo.each{ |key,value|
      file.puts"key=>#{key} value=>#{value}\n\n"  
    }
    file.close
  end


  #代表ベクトルを表示
  def print
    p @daihyo
  end

end  #class_end

#------------------------------------main-----------------------------------------

data = Array.new
daihyo = {}

game = Logkaiseki.new
game.kaiseki
data = game.return_data
daihyo = game.return_daihyo

lvq = LVQ.new(daihyo,data)
2.times do #LVQを1000回行う
lvq.lvq
end
lvq.daihyo_output
