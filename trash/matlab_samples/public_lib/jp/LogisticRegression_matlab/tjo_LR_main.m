function yvec=tjo_LR_main(xvec)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ロジスティック回帰分類器 by Takashi J. OZAKI %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 非常に単純な2次元のロジスティック回帰の実装コードです。
% 試しに yvec=tjo_LR_main([2;2]) とコマンドラインで入力してみて下さい。
% 綺麗な線形分離関数パターンがプロットされるはずです。

% ロジスティック回帰は「回帰」と名付けられていますが、やっていることは
% 2値クラス（もしくは複数クラス）分類を行う純然たる分類器です。
% ロジスティック分布関数＝シグモイド関数を用いて2値クラスを非線形に学習し、
% 連続分布する分離超平面群を算出することで、単なる2値クラス分類を行うだけでなく
% 「連続量（確率）」として2値クラス分類を表現することを可能にしてます。
% 即ち、0 or 1ではなく例えば0.25, 0.80といった「どれくらいの確率でそれぞれの
% クラスに分類されるか」を表すことができます。
% ただしこの方法論はSVMのマージンに対して適用することもできるため、
% 必ずしもロジスティック回帰独自のものではない点に注意が必要です。

% ロジスティック回帰の基本的な発想は、ロジット・モデルによる区間[0,1]の
% 一般化線形モデル回帰です。即ち、
% 
% log(p/1-p) = b0 + b1*x
% 
% なるロジット変換線形モデルを仮定すると、pの確率分布は上の式を変形して
% 
% P(X <= x) = 1 / (1 + exp(b0 + b1*x))
% 
% なるロジスティック分布に従います。そこで1番目の式を普通に最小二乗法で
% 解けば通常の一般化線形モデル回帰になるのですが、これをガチガチに機械学習
% 分類器として使ってしまおうというのがロジスティック回帰です。
% 
% 発想としてはよくあるベイズ推定の応用です。まず、ある特徴ベクトルxが
% クラスC1もしくはC2のどちらかに入る事後確率を考えます。この場合、
% 
% p(C1|x) = y(x) = σ(w'*x)
% （ただしσ(a) = 1 / (1 + exp(-a))なるシグモイド関数）
% 
% と表せます。
% そこで教師信号x_n、正解ラベル信号t_n（0 or 1で定義）によって、
% 重みベクトルwを学習させることを考えてみます。最尤推定のやり方同様に、
% wに関する尤度関数は
% 
% p(t|w) = Πy_n^(t_n){1-y_n}^(1-t_n)
% 
% と書き表せます。そこで誤差関数（尤度関数の負の対数）を考えると、
% 
% E(w) = -ln{p(t|w)} = -Σ{t_n*ln(y_n) + (1-t_n)*ln(1-y_n)}
% 
% と表せます。この誤差関数を最小化するwを解析的に求めることはできないので、
% 反復重み付き最小二乗法(IRLS)と呼ばれるヒューリスティック解法を用います。
% 
% そのためには∇E(w)とH = ∇∇E(w)の2つを求めます。それぞれ
% 
% ∇E(w) = Σ(y_n-t_n)*x_n
% H = Σy_n*(1-y_n)*x_n*x_n'
% 
% と求まります。一方重みベクトルwの更新式は
% 
% w_new = w_old - inverse(H)*∇E(w)
% （inverse()は逆行列演算）
% 
% なるIRLS法に従う最急降下法チックな形で表されます。
% なお、上式の通り逆行列の演算が必要となるため、
% Javaなどでは線形代数演算のライブラリを用意する必要があります。
% ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
% 決定規則は最初に現れた式の通り、
%  
% p(C_n|x) = σ(w'*x)
% 
% で表されます。決定境界は0.5です（シグモイド関数の中点）。
% この値をコントロールして、少しだけ学習則を改変してやることで、
% 多クラス分類も可能になります。

%%
%%%%%%%%%%%%%%%%%
% 教師信号の設定 %
%%%%%%%%%%%%%%%%%
% 他の機械学習分類器のコードサンプルと全く同じです。
% ones関数でxy座標上の4つの象限に基準点をばら撒き、
% rand関数でばらつきを与えてあります。

c=8; % rand関数のばらつきの大きさを決めます。

q1=[(1*ones(1,10)+c*rand(1,10));(1*ones(1,10)+c*rand(1,10));ones(1,10)];    % 第1象限
q2=[(-1*ones(1,10)-c*rand(1,10));(1*ones(1,10)+c*rand(1,10));ones(1,10)];   % 第2象限
q3=[(-1*ones(1,10)-c*rand(1,10));(-1*ones(1,10)-c*rand(1,10));ones(1,10)];  % 第3象限
q4=[(1*ones(1,10)+c*rand(1,10));(-1*ones(1,10)-c*rand(1,10));ones(1,10)];   % 第4象限

x1_list=[q1 q2 q4]; % 厳密には非線形ではないけど、偏りのあるパターンがGroup 1
x2_list=[q3];       % 残りの第3象限がGroup 2

c1=size(x1_list,2); % x1_listの要素数
c2=size(x2_list,2); % x2_listの要素数
clength=c1+c2; % 全要素数：この後毎回参照することになります。

% 正解信号：x1とx2とで分離したいので、対応するインデックスに1と-1を割り振ります。
x_list=[x1_list x2_list]; % x1_listとx2_listを行方向に並べてまとめます。
y_list=[ones(c1,1);zeros(c2,1)]; % 正解信号をx1:1, x2:0として列ベクトルにまとめます。

%%%%%%%%%%%%%%%
% 可視化パート %
%%%%%%%%%%%%%%%
pause on;

figure(1); % プロットウィンドウを1つ作る
scatter(x1_list(1,:),x1_list(2,:),100,'ko');hold on;
scatter(x2_list(1,:),x2_list(2,:),100,'k+');
xlim([-10 10]);
ylim([-10 10]);

pause(3);
%%%%%%%%%%%%%%%%%%%%%
% 可視化パート終わり %
%%%%%%%%%%%%%%%%%%%%%
%%

wvec=[0;0;1];

%%
[wvec,nE,H]=tjo_LR_train(wvec,x_list,y_list,clength);

yvec=tjo_LR_predict(wvec,[xvec;1]);

%%
%%%%%%%%%%%%%%%
% 可視化パート %
%%%%%%%%%%%%%%%
figure(2); % プロットウィンドウを1つ作る
scatter(x1_list(1,:),x1_list(2,:),100,'ko');hold on;
scatter(x2_list(1,:),x2_list(2,:),100,'k+');hold on;
xlim([-10 10]);
ylim([-10 10]);

if(yvec > 0.5) % テスト信号xvecがGroup 1なら赤い○でプロット
    scatter(xvec(1),xvec(2),200,'red');hold on;
    fprintf(1,'\n\nGroup 1\n\n');
elseif(yvec < 0.5) % テスト信号xvecがGroup 2なら赤い＋でプロット
    scatter(xvec(1),xvec(2),200,'red','+');hold on;
    fprintf(1,'\n\nGroup 2\n\n');
else % テスト信号xvecが万一分離超平面上なら青い○でプロット
    scatter(xvec(1),xvec(2),200,'blue');hold on;
    fprintf(1,'\n\nOn the border\n\n');
end;

% コンター（等高線）プロット。難しいので詳細はMatlabヘルプをご参照下さい。
[xx,yy]=meshgrid(-10:0.1:10,-10:0.1:10);
cxx=size(xx,2);
zz=zeros(cxx,cxx);
for p=1:cxx
    for q=1:cxx
        zz(p,q)=tjo_LR_predict(wvec,[xx(p,q);yy(p,q);1]);
    end;
end;
contour(xx,yy,zz,50);hold on;

pause off;
%%%%%%%%%%%%%%%%%%%%%
% 可視化パート終わり %
%%%%%%%%%%%%%%%%%%%%%
end