-- title:  bombman80
-- author: neko
-- desc:   short description
-- script: lua

dt=0
pt=0
TSIZE=16 --tile size
COLS=30
ROWS=17
SCREEN_WIDTH=240 --px
SCREEN_HEIGHT=136
FONT_HEIGHT=12 --font height
TRANSPARENT_OBSTACLE=500 --sprite index

--bombs qualities
MAX_BOMBS=4
MAX_RANGE=4

game={state="init",level=1,menu_index=1,high_scores={},door={}}
game.high_scores={LUI="10000",MARIA="2500",NOX="1300",AAA="150",JJJ="2400"}

solids_start=64
solids_end=96-1
solids={}
for i=solids_start,solids_end do solids[i]=true end


breaks={66,67,82,83}
breakables={}
for _,v in ipairs(breaks) do breakables[v]=true end

function is_solid(x,y)
	return solids[mget(x//8,y//8)]
end

function is_breakable(x,y)
	return breakables[mget(x//8,y//8)]
end

DOOR_SPR=032

--destroys tiles
function dstr(x,y)
	local cx=x//8
	local cy=y//8
	local idx=mget(x//8,y//8)
	if idx==0 then
		return true
	elseif breakables[idx] then
		clear_map(cx,cy,2,2)
		show_bonuses(cx,cy)
		return true
	end
	return false
end

function is_empty(x,y)
	return mget(x//8,y//8)==0
end

--randomize a table
function shuffle(tbl)
	size = #tbl
	for i = size, 1, -1 do
		local rand = math.random(size)
		tbl[i], tbl[rand] = tbl[rand], tbl[i]
	end
	return tbl
end

player={
	x=0,y=0,dx=0,dy=0,spd=1,
	box={left=0,top=0,w=16,h=16},
	rect={x1=0,y1=0,x2=0,y2=0},
	lives=3,
	bombs=1,
	max_bombs=1,
	range=1,
	invincible=0,
}

player.update=function(self,dt)
	self.x=self.x+self.dx
	collision(self,0,self.box)
	
	self.y=self.y+self.dy
	collision(self,1,self.box)
	
	self.dx=0
	self.dy=0
	self.rect.x1=self.box.left+self.x
	self.rect.y1=self.box.top+self.y
	self.rect.x2=self.box.left+self.box.w+self.x
	self.rect.y2=self.box.top+self.box.h+self.y

	if self.invincible>0 then
		self.invincible=self.invincible-1
	end
end

player.draw=function(self)
	if self.invincible>0 then
		if self.invincible%24==0 then
			spr(256,self.x,self.y,0,1,0,0,2,2)
		end
	else
		spr(256,self.x,self.y,0,1,0,0,2,2)
	end
	--rectb(self.x+self.box.left,self.y+self.box.top,self.box.w,self.box.h,5)
end

player.add_bomb=function(self)
	if player.bombs+1>player.max_bombs then
		player.bombs=player.max_bombs
		return false
	else
		player.bombs=player.bombs+1
		return true
	end
end

player.take_bomb=function(self)
	if player.bombs>0 then
		player.bombs=player.bombs-1
		return true
	end
	return false
end

player.hit=function(self)
	if self.invincible>0 then
		return
	end
	--self.x=START_X
	--self.y=START_Y
	self.lives=self.lives-1
	if self.lives<=0 then
		game.state="over"
	else
		self.invincible=100
	end
end

bombs={}

Bomb={
	mt={},
	new=function(newx,newy,range)
		local b={ x=newx,y=newy,state=0, t=100,range=range,explosions={},rect={x1=newx,y1=newx,x2=newx+TSIZE,y2=newy+TSIZE} }
		setmetatable(b,Bomb.mt)
		return b
	end,
	place=function(x,y,range)
		local b=Bomb.new(x,y,range)
		return b
	end,
	
	draw=function(self)
		if self.state==0 then
			spr(258,self.x,self.y,0,1,0,0,2,2)
		elseif self.state==1 then
			for _,s in ipairs(self.explosions) do
				spr(s.s,s.x,s.y,0,2)
			end
		end
	end,
	update=function(self)
		self.t=self.t-1
		--change to explosion
		if self.t<=0 then
			if self.state==0 then
				self.state=1
				self.t=30
				self:explode()				
			else
				self.state=2 --delete
			end
		end
		
		if self.state==1 then
			for _,e in ipairs(self.explosions) do
				if player.invincible<=0 and rect_col(player.rect, e.rect) then
					trace("touched explosion!")
					player:hit()
				end
			end
		end
	end,
	
	explode=function(self)
		function chain(x,y,s)
			local empty=is_empty(x,y)
			local broken=dstr(x,y)==true
		 if broken then
				self:add_explosion(s,x,y)
			end
			return not(empty or broken)
		end
		
		---[-1,1]
		for s=-1,1,2 do
			for x=1,self.range do
				if chain(self.x+x*TSIZE*s,self.y,288) then
					break
				end
			end
		end
		
		for s=-1,1,2 do
			for y=1,self.range do
				if chain(self.x,self.y+y*TSIZE*s,305) then
					break
				end
			end
		end
		self:add_explosion(289,self.x,self.y)
	end,
	
	add_explosion=function(self,idx,x,y)
		table.insert(self.explosions,
		{s=idx,x=x,y=y,w=TSIZE,h=TSIZE, rect={x1=x,y1=y,x2=x+TSIZE,y2=y+TSIZE}})
	end
}
Bomb.mt.__index=Bomb

function place_bomb(x,y,range)
	if player.bombs>0 and mget(x//8,y//8)==0 and not(has_entities(x,y)) then
		if player:take_bomb() then
			local bomb=Bomb.place(x,y,range)
			local cx=x//8
			local cy=y//8
			bombs[#bombs+1]=bomb
		end
	end
end

function update_bombs(dt)
	for i=#bombs,1,-1 do
		if bombs[i].state==2 then
			table.remove(bombs,i)
			player:add_bomb()
		end
	end

	for _,bomb in ipairs(bombs) do
		bomb:update(dt)
	end
end

bonuses={}
Bonus={
	mt={},
	new=function(newx,newy,type)
		local b={ x=newx,y=newy,rect={x1=newx,y1=newy,x2=newx+TSIZE,y2=newy+TSIZE},visible=false,consumed=false,type=type }
		if type=="number" then
			b.s=290
		elseif type=="range" then
			b.s=292
		end
		setmetatable(b,Bonus.mt)
		return b
	end,
	draw=function(self)
		if self.visible then
			spr(self.s,self.x,self.y,0,1,0,0,2,2)
		end
	end,
	update=function(self,dt)
		if self.visible==false and mget(self.x//8,self.y//8)==0 then
			self.visible=true
		end
		if self.visible and rect_col(player.rect, self.rect) then
			trace("picked up a bonus!")
			if self.type=="number" then
				player.max_bombs=player.max_bombs+1
				if player.max_bombs>MAX_BOMBS then
					player.max_bombs=MAX_BOMBS
				end
				player.bombs=player.max_bombs
			elseif self.type=="range" then
				player.range=player.range+1
				if player.range>MAX_RANGE then
					player.range=MAX_RANGE
				end
			end
			self.consumed=true
			self.visible=false
		end
	end,
}
Bonus.mt.__index=Bonus

function add_bonuses()
	bonuses={}
	trace("adding bonuses")
	local d_tiles={}
	for x=0,COLS-1,2 do
		for y=0,ROWS-1,2 do
			if breakables[mget(x,y)] then
				table.insert(d_tiles,{x=x*8,y=y*8})
			end
		end
	end
	d_tiles = shuffle(d_tiles)
	place_bonus("number",3,3,d_tiles)
	place_bonus("range",3,3,d_tiles)
end

function place_bonus(type,min,max,d_tiles)
	local cnt=math.random(min,max)
	for i=1,cnt do
		if i > #d_tiles then break end
		local bonus = Bonus.new(d_tiles[i].x,d_tiles[i].y,type)
		table.insert(bonuses,bonus)
		table.remove(d_tiles,i)
	end
end

function update_bonuses(dt)
	for i=#bonuses,1,-1 do
		if bonuses[i].consumed then
			table.remove(bonuses,i)
		else
			bonuses[i]:update(dt)
		end
	end
end

function show_bonuses(cx,cy)
	for _,bonus in ipairs(bonuses) do
		if bonus.visible==false then
			if bonus.x==cx//8 and bonus.y==cy//8 then
				bonus.visible=true
			end
		end
	end
end

function collision(o,dir,box)
	local c=8
	local startx=(o.x+o.box.left)//c
	local endx=(o.x+o.box.left+box.w-1)//c
	local starty=(o.y+box.top)//c
	local endy=(o.y+box.top+box.h-1)//c
	
	for j=starty,endy do
		for i=startx,endx do
			if is_solid(i*c,j*8) then
				if dir==0 then
					if o.dx>0 then o.x=i*c-box.w-box.left end
					if o.dx<0 then o.x=i*c+c-box.left end
				else
					if o.dy>0 then o.y=j*c-box.h-box.top end
					if o.dy<0 then o.y=j*c+c-box.top end
				end
			end
		end
	end
end

function rect_col(a,b)
	if a.x1<b.x2 and a.x2>b.x1 and a.y1<b.y2 and a.y2>b.y1 then
		return true
	end
	return false
end

function draw_gui()
	if game.state=="over" then
		print("GAME OVER", SCREEN_WIDTH//2-24,SCREEN_HEIGHT//2-10)
	end
	local title="BOMBMAN 80"
	print(title,(SCREEN_WIDTH-text_width(title))//2,116)
	print("LIVES "..player.lives,8,128)
	--print("LOC "..string.format("%0.1f",player.x)..", "..string.format("%0.1f",player.y),148,128)
	print("BOMBS "..player.bombs.."/"..player.max_bombs,174,128)
end

function has_entities(x,y)
	for _,b in ipairs(bombs) do
		if x>b.rect.x1 and y>b.rect.y1 and x<b.rect.x2 and y<b.rect.y2 then
			return true
		end
	end
	return false
end

function text_width(str)
	return print(str,0,-6)
end

function draw_menu_element(str,number,color)
	print(str, (SCREEN_WIDTH-text_width(str))//2, 24+FONT_HEIGHT*number,color)
end

function draw_menu()
	cls(0)
	local title="BOMBMAN 80"
	local elements={"New Game","Settings","High Scores","Quit"}

	if btnp(1) then game.menu_index = game.menu_index+1 end
	if btnp(0) then game.menu_index = game.menu_index-1 end
	if game.menu_index <= 0 then game.menu_index=#elements end
	if game.menu_index > #elements then game.menu_index=1 end
	if btnp(4) then 
		if game.menu_index==1 then
			game.state="start"
			return
		elseif game.menu_index==2 then
			game.state="settings"
			return
		elseif game.menu_index==3 then
			game.state="high_scores"
			return
		elseif game.menu_index==4 then
			exit()
		end
	end

	print(title, (SCREEN_WIDTH-text_width(title))//2, 8)
	local color=15
	for i,e in ipairs(elements) do
		if i==game.menu_index then
			color=6
		else
			color=15
		end
		draw_menu_element(e,i,color)
	end
end

function draw_high_scores()
	cls(0)
	local title="HIGH SCORES"
	local anykey="press x key to return"
	print(title,(SCREEN_WIDTH-text_width(title))//2, 0)
	print(anykey,(SCREEN_WIDTH-text_width(anykey))//2, SCREEN_HEIGHT-24)
	local i=0
	for name,score in pairs(game.high_scores) do
		print(name.." "..score, 96, 24+i*FONT_HEIGHT)
		i=i+1
	end

	if btnp(5) then
		game.state="menu"
		return
	end
end

function load_level(number)
	load_map(number)
	add_bonuses()
	for r=0,ROWS-1 do
		for c=0,COLS-1 do
			if mget(c,r)==2 then
				player.x=c*8
				player.y=r*8
				clear_map(c,r,2,2)
			end
		end
	end
end

function load_map(number)
	clear_map(0,0,COLS,ROWS)
	local sc=COLS*number
	local sr=(number//8)*ROWS

	copy_map(sc,sr,0,0,COLS,ROWS)
end

function clear_map(dc,dr,w,h)
	for r=0,h-1 do
		for c=0,w-1 do
			mset(dc+c,dr+r,0)
		end
	end
end

function copy_map(sc,sr,dc,dr,w,h)
	for r=0,h-1 do
		for c=0,w-1 do
			mset(dc+c,dr+r,mget(sc+c,sr+r))
		end
	end
end

function init()
	pt=time()

	game.state="menu"
end

init()

function TIC()
	local now=time()
	dt=(now-pt)/1000
	pt=now
	
	local p=player

	if game.state=="playing" then
		--input
		if btn(0) then p.dy=-p.spd end
		if btn(1) then p.dy=p.spd end
		if btn(2) then p.dx=-p.spd end
		if btn(3) then p.dx=p.spd end
		if btnp(4) then 
		place_bomb((p.x+TSIZE/2)//TSIZE*TSIZE, (p.y+TSIZE/2)//TSIZE*TSIZE,p.range)
		end

		--update
		p:update(dt)
		update_bombs(dt)
		update_bonuses(dt)

		--draw
		cls(13)
		map()
		
		for _,bomb in ipairs(bombs) do
			bomb:draw()
		end

		for _,bonus in ipairs(bonuses) do
			bonus:draw()
		end
		
		p:draw()

		draw_gui()

		if mget(player.x//8,player.y//8)==DOOR_SPR then
			game.state="start"
			game.level=game.level+1
		end
	elseif game.state=="menu" then
		draw_menu()
	elseif game.state=="start" then
		load_level(game.level)
		game.state="playing"
	elseif game.state=="over" then
	elseif game.state=="high_scores" then
		draw_high_scores()
	end
	
end
