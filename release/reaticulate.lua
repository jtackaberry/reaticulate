-- This is generated code and not meant for human consumption.
-- 
-- See https://github.com/jtackaberry/reaticulate/ for original source code.
metadata=(function()
return {_VERSION='0.5.13'}end)()
rtk=(function()
__mod_rtk_core=(function()
__mod_rtk_log=(function()
local log={levels={[50]='CRITICAL',[40]='ERROR',[30]='WARNING',[20]='INFO',[10]='DEBUG',[9]='DEBUG2',},level=40,timer_threshold=20,named_timers=nil,timers={},queue={},wall_time_start=os.time(),reaper_time_start=reaper.time_precise(),}log.wall_time_start=log.wall_time_start+(log.reaper_time_start-math.floor(log.reaper_time_start))log.CRITICAL=50
log.ERROR=40
log.WARNING=30
log.INFO=20
log.DEBUG=10
log.DEBUG2=9
function log.critical(fmt,...)log._log(log.CRITICAL,nil,fmt,...)end
function log.error(fmt,...)log._log(log.ERROR,nil,fmt,...)end
function log.warning(fmt,...)log._log(log.WARNING,nil,fmt,...)end
function log.info(fmt,...)log._log(log.INFO,nil,fmt,...)end
function log.debug(fmt,...)log._log(log.DEBUG,nil,fmt,...)end
function log.debug2(fmt,...)log._log(log.DEBUG2,nil,fmt,...)end
local function enqueue(msg)local qlen=#log.queue
if qlen==0 then
reaper.defer(log.flush)end
log.queue[qlen+1]=msg
end
local function _get_precise_duration_string(t)if t<0.1 then
return string.format('%.03f', t)elseif t<1 then
return string.format('%.02f', t)elseif t<10 then
return string.format('%.01f', t)else
return string.format('%.0f', t)end
end
function log.exception(fmt,...)log._log(log.ERROR,debug.traceback(),fmt,...)log.flush()end
function log.trace(level)if log.level<=(level or log.DEBUG)then
enqueue(debug.traceback() .. '\n')end
end
function log._log(level,tail,fmt,...)if level<log.level then
return
end
local r,err=pcall(string.format,fmt,...)if not r then
log.exception("exception formatting log string '%s': %s", fmt, err)return
end
local now=reaper.time_precise()local time=log.wall_time_start+(now-log.reaper_time_start)local ftime=math.floor(time)local msecs=string.sub(time-ftime,3,5)local label='[' .. log.level_name(level) .. ']'local prefix=string.format('%s.%s %-9s ', os.date('%H:%M:%S', ftime), msecs, label)if level<=log.timer_threshold and #log.timers>0 then
local timer=log.timers[#log.timers]
local total=_get_precise_duration_string((now-timer[1])*1000)local last=_get_precise_duration_string((now-timer[2])*1000)local name=timer[3] and string.format(' [%s]', timer[3]) or ''prefix=prefix .. string.format('(%s / %s ms%s) ', last, total, name)timer[2]=now
end
local msg=prefix .. err .. '\n'if tail then
msg=msg .. tail .. '\n'end
enqueue(msg)end
function log.log(level,fmt,...)return log._log(level,nil,fmt,...)end
function log.logf(level,fmt,func)if level>=log.level then
return log._log(level,nil,fmt,func())end
end
function log.flush()local str=table.concat(log.queue)if #str>0 then
reaper.ShowConsoleMsg(str)end
log.queue={}end
function log.level_name(level)return log.levels[level or log.level] or 'UNKNOWN'end
function log.clear(level)if not level or log.level<=level then
reaper.ShowConsoleMsg("")log.queue={}end
end
function log.time_start(name)if log.level>log.timer_threshold then
return
end
local now=reaper.time_precise()table.insert(log.timers,{now,now,name})if name then
if not log.named_timers then
log.named_timers={}log.named_timers_order={}end
if not log.named_timers[name] then
log.named_timers[name]={0,0}log.named_timers_order[#log.named_timers_order+1]=name
end
end
end
function log.time_end(fmt,...)if fmt then
log._log(log.DEBUG,nil,fmt,...)end
log.time_end_report_if(false)end
function log.time_end_report(fmt,...)if fmt then
log._log(log.DEBUG,nil,fmt,...)end
log.time_end_report_if(true)end
function log.time_end_report_if(show,fmt,...)if log.level>log.timer_threshold then
return
end
if fmt and show then
log._log(log.DEBUG,nil,fmt,...)end
assert(#log.timers > 0, "time_end() with no previous time_start()")local t0,_,name=table.unpack(table.remove(log.timers))if log.named_timers then
if name then
local delta=reaper.time_precise()-t0
local current=log.named_timers[name]
if not current then
log.named_timers[name]={current+delta,1}else
log.named_timers[name]={current[1]+delta,current[2]+1}end
end
if show and log.level<=log.INFO then
local output=''local maxname=0
local maxtime=0
local times={}for i,name in ipairs(log.named_timers_order)do
local duration,_=table.unpack(log.named_timers[name])times[#times+1]=string.format('%.4f ms', duration * 1000)maxtime=math.max(maxtime,#times[#times])maxname=math.max(maxname,#name)end
local fmt=string.format('       %%2d. %%%ds: %%%ds  (%%d)\n', maxname, maxtime)for i,name in ipairs(log.named_timers_order)do
local _,count=table.unpack(log.named_timers[name])output=output..string.format(fmt,i,name,times[i],count)end
enqueue(output)end
end
if #log.timers==0 then
log.named_timers=nil
end
end
return log
end)()

local log=__mod_rtk_log
local rtk={touchscroll=false,smoothscroll=true,touch_activate_delay=0.1,long_press_delay=0.5,double_click_delay=0.5,tooltip_delay=0.5,light_luma_threshold=0.6,debug=false,window=nil,has_js_reascript_api=(reaper.JS_Window_GetFocus~=nil),has_sws_extension=(reaper.BR_Win32_GetMonitorRectFromRect~=nil),script_path=nil,reaper_hwnd=nil,tick=0,fps=30,focused_hwnd=nil,focused=nil,theme=nil,_dest_stack={},_image_paths={},_animations={},_animations_len=0,_easing_functions={},_frame_count=0,_frame_time=nil,_modal=nil,_touch_activate_event=nil,_last_traceback=nil,_last_error=nil,_quit=false,_refs=setmetatable({}, {__mode='v'}),_run_soon=nil,_reactive_attr={},}rtk.scale=setmetatable({user=nil,_user=1.0,system=nil,reaper=1.0,framebuffer=nil,value=1.0,_discover=function()local inifile=reaper.get_ini_file()local ini,err=rtk.file.read(inifile)if not err then
rtk.scale.reaper = ini:match('uiscale=([^\n]*)') or 1.0
end
local ok, dpi=reaper.ThemeLayout_GetLayout("mcp", -3)if not ok then
return
end
dpi=math.ceil(tonumber(dpi)/rtk.scale.reaper)rtk.scale.system=dpi/256.0
if not rtk.scale.framebuffer then
if rtk.os.mac and dpi==512 then
rtk.scale.framebuffer=2
else
rtk.scale.framebuffer=1
end
end
rtk.scale._calc()end,_calc=function()local value=rtk.scale.user*rtk.scale.system*rtk.scale.reaper
rtk.scale.value=math.ceil(value*100)/100.0
end,},{__index=function(t,key)return key=='user' and t._user or nil
end,__newindex=function(t,key,value)if key=='user' then
if value~=t._user then
t._user=value
rtk.scale._calc()if rtk.window then
rtk.window:queue_reflow()end
end
else
rawset(t,key,value)end
end
})rtk.dnd={dragging=nil,droppable=nil,dropping=nil,arg=nil,buttons=nil,}local _os=reaper.GetOS():lower():sub(1,3)rtk.os={mac = (_os == 'osx' or _os == 'mac'),windows=(_os=='win'),linux = (_os == 'lin' or _os == 'oth'),bits=32,}rtk.mouse={BUTTON_LEFT=1,BUTTON_MIDDLE=64,BUTTON_RIGHT=2,BUTTON_MASK=(1|2|64),x=0,y=0,down=0,state={order={},latest=nil},last={},}local _load_cursor
if rtk.has_js_reascript_api then
function _load_cursor(cursor)return reaper.JS_Mouse_LoadCursor(cursor)end
else
function _load_cursor(cursor)return cursor
end
end
rtk.mouse.cursors={UNDEFINED=0,POINTER=_load_cursor(32512),BEAM=_load_cursor(32513),LOADING=_load_cursor(32514),CROSSHAIR=_load_cursor(32515),UP_ARROW=_load_cursor(32516),SIZE_NW_SE=_load_cursor(rtk.os.linux and 32643 or 32642),SIZE_SW_NE=_load_cursor(rtk.os.linux and 32642 or 32643),SIZE_EW=_load_cursor(32644),SIZE_NS=_load_cursor(32645),MOVE=_load_cursor(32646),INVALID=_load_cursor(32648),HAND=_load_cursor(32649),POINTER_LOADING=_load_cursor(32650),POINTER_HELP=_load_cursor(32651),REAPER_FADEIN_CURVE=_load_cursor(105),REAPER_FADEOUT_CURVE=_load_cursor(184),REAPER_CROSSFADE=_load_cursor(463),REAPER_DRAGDROP_COPY=_load_cursor(182),REAPER_DRAGDROP_RIGHT=_load_cursor(1011),REAPER_POINTER_ROUTING=_load_cursor(186),REAPER_POINTER_MOVE=_load_cursor(187),REAPER_POINTER_MARQUEE_SELECT=_load_cursor(488),REAPER_POINTER_DELETE=_load_cursor(464),REAPER_POINTER_LEFTRIGHT=_load_cursor(465),REAPER_POINTER_ARMED_ACTION=_load_cursor(434),REAPER_MARKER_HORIZ=_load_cursor(188),REAPER_MARKER_VERT=_load_cursor(189),REAPER_ADD_TAKE_MARKER=_load_cursor(190),REAPER_TREBLE_CLEF=_load_cursor(191),REAPER_BORDER_LEFT=_load_cursor(417),REAPER_BORDER_RIGHT=_load_cursor(418),REAPER_BORDER_TOP=_load_cursor(419),REAPER_BORDER_BOTTOM=_load_cursor(421),REAPER_BORDER_LEFTRIGHT=_load_cursor(450),REAPER_VERTICAL_LEFTRIGHT=_load_cursor(462),REAPER_GRID_RIGHT=_load_cursor(460),REAPER_GRID_LEFT=_load_cursor(461),REAPER_HAND_SCROLL=_load_cursor(429),REAPER_FIST_LEFT=_load_cursor(430),REAPER_FIST_RIGHT=_load_cursor(431),REAPER_FIST_BOTH=_load_cursor(453),REAPER_PENCIL=_load_cursor(185),REAPER_PENCIL_DRAW=_load_cursor(433),REAPER_ERASER=_load_cursor(472),REAPER_BRUSH=_load_cursor(473),REAPER_ARP=_load_cursor(502),REAPER_CHORD=_load_cursor(503),REAPER_TOUCHSEL=_load_cursor(515),REAPER_SWEEP=_load_cursor(517),REAPER_FADEIN_CURVE_ALT=_load_cursor(525),REAPER_FADEOUT_CURVE_ALT=_load_cursor(526),REAPER_XFADE_WIDTH=_load_cursor(528),REAPER_XFADE_CURVE=_load_cursor(529),REAPER_EXTMIX_SECTION_RESIZE=_load_cursor(530),REAPER_EXTMIX_MULTI_RESIZE=_load_cursor(531),REAPER_EXTMIX_MULTISECTION_RESIZE=_load_cursor(532),REAPER_EXTMIX_RESIZE=_load_cursor(533),REAPER_EXTMIX_ALLSECTION_RESIZE=_load_cursor(534),REAPER_EXTMIX_ALL_RESIZE=_load_cursor(535),REAPER_ZOOM=_load_cursor(1009),REAPER_INSERT_ROW=_load_cursor(1010),REAPER_RAZOR=_load_cursor(599),REAPER_RAZOR_MOVE=_load_cursor(600),REAPER_RAZOR_ADD=_load_cursor(601),REAPER_RAZOR_ENVELOPE_VERTICAL=_load_cursor(202),REAPER_RAZOR_ENVELOPE_RIGHT_TILT=_load_cursor(203),REAPER_RAZOR_ENVELOPE_LEFT_TILT=_load_cursor(204),}local FONT_FLAG_BOLD=string.byte('b')local FONT_FLAG_ITALICS=string.byte('i') << 8
local FONT_FLAG_UNDERLINE=string.byte('u') << 16
rtk.font={BOLD=FONT_FLAG_BOLD,ITALICS=FONT_FLAG_ITALICS,UNDERLINE=FONT_FLAG_UNDERLINE,multiplier=1.0
}rtk.keycodes={UP=30064,DOWN=1685026670,LEFT=1818584692,RIGHT=1919379572,RETURN=13,ENTER=13,SPACE=32,BACKSPACE=8,ESCAPE=27,TAB=9,HOME=1752132965,END=6647396,INSERT=6909555,DELETE=6579564,F1=26161,F2=26162,F3=26163,F4=26164,F5=26165,F6=26166,F7=26167,F8=26168,F9=26169,F10=6697264,F11=6697265,F12=6697266,}rtk.themes={dark={name='dark',dark=true,light=false,bg='#252525',default_font={'Calibri', 18},accent='#47abff',accent_subtle='#306088',tooltip_bg='#ffffff',tooltip_text='#000000',tooltip_font={'Segoe UI (TrueType)', 16},text='#ffffff',text_faded='#bbbbbb',text_font=nil,button='#555555',heading=nil,heading_font={'Calibri', 26},button_label='#ffffff',button_font=nil,button_gradient_mul=1,button_tag_alpha=0.32,button_normal_gradient=-0.37,button_normal_border_mul=0.7,button_hover_gradient=0.17,button_hover_brightness=0.9,button_hover_mul=1,button_hover_border_mul=1.1,button_clicked_gradient=0.47,button_clicked_brightness=0.9,button_clicked_mul=0.85,button_clicked_border_mul=1,entry_font=nil,entry_bg='#5f5f5f7f',entry_placeholder='#ffffff7f',entry_border_hover='#3a508e',entry_border_focused='#4960b8',entry_selection_bg='#0066bb',popup_bg=nil,popup_overlay='#00000040',popup_bg_brightness=1.3,popup_shadow='#11111166',popup_border='#385074',slider='#2196f3',slider_track='#5a5a5a',slider_font=nil,slider_tick_label=nil,},light={name='light',light=true,dark=false,accent='#47abff',accent_subtle='#a1d3fc',bg='#dddddd',default_font={'Calibri', 18},tooltip_font={'Segoe UI (TrueType)', 16},tooltip_bg='#ffffff',tooltip_text='#000000',button='#dedede',button_label='#000000',button_gradient_mul=1,button_tag_alpha=0.15,button_normal_gradient=-0.28,button_normal_border_mul=0.85,button_hover_gradient=0.12,button_hover_brightness=1,button_hover_mul=1,button_hover_border_mul=0.9,button_clicked_gradient=0.3,button_clicked_brightness=1.0,button_clicked_mul=0.9,button_clicked_border_mul=0.7,text='#000000',text_faded='#555555',heading_font={'Calibri', 26},entry_border_hover='#3a508e',entry_border_focused='#4960b8',entry_bg='#00000020',entry_placeholder='#0000007f',entry_selection_bg='#9fcef4',popup_bg=nil,popup_bg_brightness=1.5,popup_shadow='#11111122',popup_border='#385074',slider='#2196f3',slider_track='#5a5a5a',}}local function _postprocess_theme()local iconstyle=rtk.color.get_icon_style(rtk.theme.bg)rtk.theme.iconstyle=iconstyle
for k,v in pairs(rtk.theme)do
if type(v) == 'string' and v:byte(1) == 35 then
rtk.theme[k]={rtk.color.rgba(v)}end
end
end
function rtk.add_image_search_path(path,iconstyle)path=path:gsub('[/\\]$', '') .. '/'if not path:match('^%a:') and not path:match('^[\\/]') then
path=rtk.script_path..path
end
if iconstyle then
assert(iconstyle == 'dark' or iconstyle == 'light', 'iconstyle must be either light or dark')else
iconstyle='nostyle'end
local paths=rtk._image_paths[iconstyle]
if not paths then
paths={}rtk._image_paths[iconstyle]=paths
end
paths[#paths+1]=path
end
function rtk.set_theme(name,overrides)name=name or rtk.theme.name
assert(rtk.themes[name], 'rtk: theme "' .. name .. '" does not exist in rtk.themes')rtk.theme={}table.merge(rtk.theme,rtk.themes[name])if overrides then
table.merge(rtk.theme,overrides)end
_postprocess_theme()end
function rtk.set_theme_by_bgcolor(color,overrides)local name=rtk.color.luma(color) > rtk.light_luma_threshold and 'light' or 'dark'overrides=overrides or {}overrides.bg=color
rtk.set_theme(name,overrides)end
function rtk.set_theme_overrides(overrides)for _, name in ipairs({'dark', 'light'}) do
if overrides[name] then
rtk.themes[name]=table.merge(rtk.themes[name],overrides[name])if rtk.theme[name] then
rtk.theme=table.merge(rtk.theme,overrides[name])end
overrides[name]=nil
end
end
rtk.themes.dark=table.merge(rtk.themes.dark,overrides)rtk.themes.light=table.merge(rtk.themes.light,overrides)rtk.theme=table.merge(rtk.theme,overrides)_postprocess_theme()end
function rtk.new_theme(name,base,overrides)assert(not base or rtk.themes[base], string.format('base theme %s not found', base))assert(not rtk.themes[name], string.format('theme %s already exists', name))local theme=base and table.shallow_copy(rtk.themes[base])or {}rtk.themes[name]=table.merge(theme,overrides or {})end
function rtk.add_modal(...)if rtk._modal==nil then
rtk._modal={}end
local state=rtk.mouse.state[rtk.mouse.state.latest]
if state then
state.modaltick=rtk.tick
end
local widgets={...}for _,widget in ipairs(widgets)do
rtk._modal[widget.id]={widget,rtk.tick}end
end
function rtk.is_modal(widget)if widget==nil then
return rtk._modal~=nil
elseif rtk._modal then
local w=widget
while w do
if rtk._modal[w.id]~=nil then
return true
end
w=w.parent
end
end
return false
end
function rtk.reset_modal()rtk._modal=nil
end
function rtk.pushdest(dest)rtk._dest_stack[#rtk._dest_stack+1]=gfx.dest
gfx.dest=dest
end
function rtk.popdest()gfx.dest=table.remove(rtk._dest_stack,#rtk._dest_stack)end
local function _handle_error(err)rtk._last_error=err
rtk._last_traceback=debug.traceback()end
function rtk.onerror(err,traceback)log.error("fatal: %s\n%s", err, traceback)log.flush()error(err)end
function rtk.call(func,...)if rtk._quit then
return
end
local ok,result=xpcall(func,_handle_error,...)if not ok then
rtk.onerror(rtk._last_error,rtk._last_traceback)return
end
return result
end
function rtk.defer(func,...)if rtk._quit then
return
end
local args=table.pack(...)reaper.defer(function()rtk.call(func,table.unpack(args,1,args.n))end)end
function rtk.callsoon(func,...)if not rtk.window or not rtk.window.running then
return rtk.defer(func,...)end
local funcs=rtk._soon_funcs
if not funcs then
funcs={}rtk._soon_funcs=funcs
end
funcs[#funcs+1]={func,table.pack(...)}end
function rtk._run_soon()local funcs=rtk._soon_funcs
rtk._soon_funcs=nil
for i=1,#funcs do
local func,args=table.unpack(funcs[i])func(table.unpack(args,1,args.n))end
end
function rtk.callafter(duration,func,...)local args=table.pack(...)local start=reaper.time_precise()local function sched()if reaper.time_precise()-start>=duration then
rtk.call(func,table.unpack(args,1,args.n))elseif not rtk._quit then
reaper.defer(sched)end
end
sched()end
function rtk.quit()if rtk.window and rtk.window.running then
rtk.window:close()end
rtk._quit=true
end
rtk.version={_DEFAULT_API=1,string=nil,api=nil,major=nil,minor=nil,patch=nil,}function rtk.version.parse()local ver=__RTK_VERSION or string.format('%s.99.99', rtk.version._DEFAULT_API)local parts=ver:split('.')rtk.version.major=tonumber(parts[1])rtk.version.minor=tonumber(parts[2])rtk.version.patch=tonumber(parts[3])rtk.version.api=rtk.version.major
rtk.version.string=ver
end
function rtk.version.check(major,minor,patch)local v=rtk.version
return v.major>major or
(v.major==major and(not minor or v.minor>minor))or
(v.major==major and v.minor==minor and(not patch or v.patch>=patch))end
return rtk
end)()

local rtk=__mod_rtk_core
__mod_rtk_type=(function()
local rtk=__mod_rtk_core
__mod_rtk_middleclass=(function()
local middleclass={_VERSION='middleclass v4.1.1',}local function _createIndexWrapper(aClass,f)if f==nil then
return aClass.__instanceDict
else
return function(self,name)local value=aClass.__instanceDict[name]
if value~=nil then
return value
elseif type(f)=="function" then
return(f(self,name))else
return f[name]
end
end
end
end
local function _propagateInstanceMethod(aClass,name,f)f=name=="__index" and _createIndexWrapper(aClass, f) or f
aClass.__instanceDict[name]=f
for subclass in pairs(aClass.subclasses)do
if rawget(subclass.__declaredMethods,name)==nil then
_propagateInstanceMethod(subclass,name,f)end
end
end
local function _declareInstanceMethod(aClass,name,f)aClass.__declaredMethods[name]=f
if f==nil and aClass.super then
f=aClass.super.__instanceDict[name]
end
_propagateInstanceMethod(aClass,name,f)end
local function _tostring(self) return "class " .. self.name end
local function _call(self,...)return self:new(...)end
local function _createClass(name,super)local dict={}dict.__index=dict
local aClass={ name=name,super=super,static={},__instanceDict=dict,__declaredMethods={},subclasses=setmetatable({}, {__mode='k'})  }if super then
setmetatable(aClass.static,{__index=function(_,k)local result=rawget(dict,k)if result==nil then
return super.static[k]
end
return result
end
})else
setmetatable(aClass.static,{ __index=function(_,k)return rawget(dict,k)end })end
setmetatable(aClass,{ __index=aClass.static,__tostring=_tostring,__call=_call,__newindex=_declareInstanceMethod })return aClass
end
local function _includeMixin(aClass,mixin)assert(type(mixin)=='table', "mixin must be a table")for name,method in pairs(mixin)do
if name ~= "included" and name ~= "static" then aClass[name] = method end
end
for name,method in pairs(mixin.static or {})do
aClass.static[name]=method
end
if type(mixin.included)=="function" then mixin:included(aClass) end
return aClass
end
local DefaultMixin={__tostring=function(self) return "instance of " .. tostring(self.class) end,__gc=function(self)if type(self) == 'table' and type(self.class) == 'table' and type(self.class.finalize) == 'function' then
self:finalize()end
end,initialize=function(self,...)end,isInstanceOf=function(self,aClass)return type(aClass)=='table'and type(self)=='table'and(self.class==aClass
or type(self.class)=='table'and type(self.class.isSubclassOf)=='function'and self.class:isSubclassOf(aClass))end,static={allocate=function(self)assert(type(self)=='table', "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")local instance=setmetatable({ class=self },self.__instanceDict)if instance.__allocate then
instance:__allocate()end
return instance
end,new=function(self,...)assert(type(self)=='table', "Make sure that you are using 'Class:new' instead of 'Class.new'")local instance=self:allocate()instance:initialize(...)return instance
end,subclass=function(self,name)assert(type(self)=='table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")assert(type(name)=="string", "You must provide a name(string) for your class")local subclass=_createClass(name,self)for methodName,f in pairs(self.__instanceDict)do
_propagateInstanceMethod(subclass,methodName,f)end
subclass.initialize=function(instance,...)return self.initialize(instance,...)end
self.subclasses[subclass]=true
self:subclassed(subclass)return subclass
end,subclassed=function(self,other)end,isSubclassOf=function(self,other)return type(other)=='table' and
type(self.super)=='table' and
(self.super==other or self.super:isSubclassOf(other))end,include=function(self,...)assert(type(self)=='table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")for _,mixin in ipairs({...})do _includeMixin(self,mixin)end
return self
end
}}function middleclass.class(name,super)assert(type(name)=='string', "A name (string) is needed for the new class")return super and super:subclass(name)or _includeMixin(_createClass(name),DefaultMixin)end
setmetatable(middleclass,{ __call=function(_,...)return middleclass.class(...)end })return middleclass
end)()

local class=__mod_rtk_middleclass
rtk.Attribute={FUNCTION={},NIL={},DEFAULT={},default=nil,type=nil,calculate=nil,priority=nil,reflow=nil,redraw=nil,replaces=nil,animate=nil,get=nil,set=nil,}setmetatable(rtk.Attribute,{__call=function(self,attrs)attrs._is_rtk_attr=true
return attrs
end
})local falsemap={[false]=true,[0]=true,['0']=true,['false']=true,['False']=true,['FALSE']=true
}local typemaps={number=function(v)local n=tonumber(v)if n then
return n
elseif v == 'true' or v == true then
return 1
elseif v == 'false' or v == false then
return 0
end
end,string=tostring,boolean=function(v)if falsemap[v] then
return false
elseif v then
return true
end
end,}function rtk.Reference(attr)return {_is_rtk_reference=true,attr=attr
}end
local function register(cls,attrs)local attributes=cls.static.attributes
if attributes and attributes.__class==cls.name then
elseif cls.super then
attributes={}for k,v in pairs(cls.super.static.attributes)do
if k ~= '__class' and k ~= 'get' then
attributes[k]=table.shallow_copy(v)end
end
else
attributes={defaults={}}end
local refs={}for attr,attrtable in pairs(attrs)do
assert(attr ~= 'id' and attr ~= 'get' and attr ~= 'defaults',"attempted to assign a reserved attribute")if type(attrtable)=='table' and attrtable._is_rtk_reference then
local srcattr=attrtable.attr
attrtable={}refs[#refs+1]={attrtable,nil,srcattr,attr}else
if type(attrtable) ~='table' or not attrtable._is_rtk_attr then
attrtable={default=attrtable}end
if attributes[attr] then
attrtable=table.merge(attributes[attr],attrtable)end
for field,v in pairs(attrtable)do
if type(v)=='table' and v._is_rtk_reference then
refs[#refs+1]={attrtable,field,v.attr,attr}end
end
local deftype=type(attrtable.default)if deftype=='function' then
attrtable.default_func=attrtable.default
attrtable.default=rtk.Attribute.FUNCTION
end
if (not attrtable.type and not attrtable.calculate) or type(attrtable.type)=='string' then
attrtable.type=typemaps[attrtable.type or deftype]
end
end
attributes[attr]=attrtable
attributes.defaults[attr]=attrtable.default
end
for _,ref in ipairs(refs)do
local attrtable,field,srcattr,dstattr=table.unpack(ref)local src=attributes[srcattr]
if not attributes.defaults[dstattr] and not field then
attributes.defaults[dstattr]=attributes.defaults[srcattr]
end
if field then
attrtable[field]=src[field]
else
for k,v in pairs(src)do
attrtable[k]=v
end
end
end
attributes.__class=cls.name
attributes.get=function(attr)return attributes[attr] or rtk.Attribute.NIL
end
cls.static.attributes=attributes
end
function rtk.class(name,super,attributes)local cls=class(name,super)cls.static.register=function(attrs)register(cls,attrs)end
if attributes then
register(cls,attributes)end
return cls
end
function rtk.isa(v,cls)if type(v)=='table' and v.isInstanceOf then
return v:isInstanceOf(cls)end
return false
end
end)()

__mod_rtk_utils=(function()
local rtk=__mod_rtk_core
rtk.file={}rtk.clipboard={}rtk.gfx={}UNDO_STATE_ALL=-1
UNDO_STATE_TRACKCFG=1
UNDO_STATE_FX=2
UNDO_STATE_ITEMS=4
UNDO_STATE_MISCCFG=8
UNDO_STATE_FREEZE=16
UNDO_STATE_TRACKENV=32
UNDO_STATE_FXENV=64
UNDO_STATE_POOLEDENVS=128
UNDO_STATE_FX_ARA=256
function rtk.check_reaper_version(major,minor,exact)local curmaj=rtk._reaper_version_major
local curmin=rtk._reaper_version_minor
minor=minor<100 and minor or minor/10
if exact then
return curmaj==major and curmin==minor
else
return(curmaj>major)or(curmaj==major and curmin>=minor)end
end
function rtk.clamp(value,min,max)if min and max then
return math.max(min,math.min(max,value))elseif min then
return math.max(min,value)elseif max then
return math.min(max,value)else
return value
end
end
function rtk.clamprel(value,min,max)min=min and min<1.0 and min*value or min
max=max and max<1.0 and max*value or max
if min and max then
return math.max(min,math.min(max,value))elseif min then
return math.max(min,value)elseif max then
return math.min(max,value)else
return value
end
end
function rtk.isrel(value)return value and value>0 and value<=1.0
end
function rtk.point_in_box(x,y,bx,by,bw,bh)return x>=bx and y>=by and x<=bx+bw and y<=by+bh
end
function rtk.point_in_circle(x,y,cirx,ciry,radius)local dx=x-cirx
local dy=y-ciry
return dx*dx+dy*dy<=radius*radius
end
function rtk.open_url(url)if rtk.os.windows then
reaper.ExecProcess(string.format('cmd.exe /C start /B "" "%s"', url), -2)elseif rtk.os.mac then
os.execute(string.format('open "%s"', url))elseif rtk.os.linux then
reaper.ExecProcess(string.format('xdg-open "%s"', url), -2)else
reaper.ShowMessageBox("Sorry, I don't know how to open URLs on this operating system.","Unsupported operating system", 0
)end
end
function rtk.uuid4()return reaper.genGuid():sub(2,-2):lower()end
function rtk.file.read(fname)local f,err=io.open(fname)if f then
local contents=f:read("*all")f:close()return contents,nil
else
return nil,err
end
end
function rtk.file.write(fname,contents)local f, err=io.open(fname, "w")if f then
f:write(contents)f:close()else
return err
end
end
function rtk.file.size(fname)local f,err=io.open(fname)if f then
local size=f:seek("end")f:close()return size,nil
else
return nil,err
end
end
function rtk.file.exists(fname)return reaper.file_exists(fname)end
function rtk.clipboard.get()if not reaper.CF_GetClipboardBig then
return
end
local fast=reaper.SNM_CreateFastString("")local data=reaper.CF_GetClipboardBig(fast)reaper.SNM_DeleteFastString(fast)return data
end
function rtk.clipboard.set(data)if not reaper.CF_SetClipboard then
return false
end
reaper.CF_SetClipboard(data)return true
end
function rtk.gfx.roundrect(x,y,w,h,r,thickness,aa)thickness=thickness or 1
aa=aa or 1
w=w-1
h=h-1
if thickness==1 then
gfx.roundrect(x,y,w,h,r,aa)elseif thickness>1 then
for i=0,thickness-1 do
gfx.roundrect(x+i,y+i,w-i*2,h-i*2,r,aa)end
elseif h>=2*r then
gfx.circle(x+r,y+r,r,1,aa)gfx.circle(x+w-r,y+r,r,1,aa)gfx.circle(x+r,y+h-r,r,1,aa)gfx.circle(x+w-r,y+h-r,r,1,aa)gfx.rect(x,y+r,r,h-r*2)gfx.rect(x+w-r,y+r,r+1,h-r*2)gfx.rect(x+r,y,w-r*2,h+1)else
r=h/2-1
gfx.circle(x+r,y+r,r,1,aa)gfx.circle(x+w-r,y+r,r,1,aa)gfx.rect(x+r,y,w-r*2,h)end
end
rtk.IndexManager=rtk.class('rtk.IndexManager')function rtk.IndexManager:initialize(first,last)self.first=first
self.last=last
self._last=last-first
self._bitmaps={}self._tail_idx=nil
self._last_idx=nil
end
function rtk.IndexManager:_set(idx,value)local elem=math.floor(idx/32)+1
local count=#self._bitmaps
if elem>count then
for n=1,elem-count do
self._bitmaps[#self._bitmaps+1]=0
end
end
local bit=idx%32
if value~=0 then
self._bitmaps[elem]=self._bitmaps[elem]|(1<<bit)else
self._bitmaps[elem]=self._bitmaps[elem]&~(1<<bit)end
end
function rtk.IndexManager:set(idx,value)return self:_set(idx-self.first,value)end
function rtk.IndexManager:_get(idx)local elem=math.floor(idx/32)+1
if elem>#self._bitmaps then
return false
end
local bit=idx%32
return self._bitmaps[elem]&(1<<bit)~=0
end
function rtk.IndexManager:get(idx)return self:_get(idx-self.first)end
function rtk.IndexManager:_search_free()local start=self._last_idx<self._last and self._last_idx or 0
local bit=start%32
local startelem=math.floor(start/32)+1
for elem=1,#self._bitmaps do
local bitmap=self._bitmaps[elem]
if bitmap~=0xffffffff then
for bit=bit,32 do
if bitmap&(1<<bit)==0 then
return elem,bit
end
end
end
bit=0
end
end
function rtk.IndexManager:_next()local idx
if not self._tail_idx then
idx=0
elseif self._tail_idx<self._last then
idx=self._tail_idx+1
else
local elem,bit=self:_search_free()if elem==#self._bitmaps and bit>=self._last%32 then
return nil
end
idx=(elem-1)*32+bit
end
self._last_idx=idx
self._tail_idx=self._tail_idx and math.max(self._tail_idx,idx)or idx
self:_set(idx,1)return idx+self.first
end
function rtk.IndexManager:next(gc)local idx=self:_next()if not idx and gc then
collectgarbage('collect')idx=self:_next()end
return idx
end
function rtk.IndexManager:release(idx)self:_set(idx-self.first,0)end
math.inf=1/0
function math.round(n)return n and(n%1>=0.5 and math.ceil(n)or math.floor(n))end
function string.startswith(s,prefix,insensitive)if insensitive==true then
return s:lower():sub(1,string.len(prefix))==prefix:lower()else
return s:sub(1,string.len(prefix))==prefix
end
end
function string.split(s,delim,filter)local parts={}for word in s:gmatch('[^' .. (delim or '%s') .. ']' .. (filter and '+' or '*')) do
parts[#parts+1]=word
end
return parts
end
function string.strip(s)return s:match('^%s*(.-)%s*$')end
function string.hash(s)local hash=5381
for i=1,#s do
hash=((hash<<5)+hash)+s:byte(i)end
return hash&0x7fffffffffffffff
end
function string.count(s,sub)local c=-1
local idx=0
while idx do
_,idx=s:find(sub,idx+1)c=c+1
end
return c
end
local _table_tostring=nil
local function val_to_str(v,seen)if "string" == type(v) then
v=string.gsub(v, "\n", "\\n")if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
return "'" .. v .. "'"end
return '"' .. string.gsub(v, '"', '\\"') .. '"'else
if type(v)=='table' and not v.__tostring then
return seen[tostring(v)] and '<recursed>' or _table_tostring(v, seen)else
return tostring(v)end
return "table" == type(v) and _table_tostring(v, seen) or tostring(v)end
end
local function key_to_str(k,seen)if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
return k
else
return "[" .. val_to_str(k, seen) .. "]"end
end
_table_tostring=function(tbl,seen)local result,done={},{}seen=seen or {}local id=tostring(tbl)seen[id]=1
for k,v in ipairs(tbl)do
table.insert(result,val_to_str(v,seen))done[k]=true
end
for k,v in pairs(tbl)do
if not done[k] then
table.insert(result, key_to_str(k, seen) .. "=" .. val_to_str(v, seen))end
end
seen[id]=nil
return "{" .. table.concat( result, "," ) .. "}"end
function table.tostring(tbl)return _table_tostring(tbl)end
function table.fromstring(str)return load('return ' .. str)()end
function table.merge(dst,src)for k,v in pairs(src)do
dst[k]=v
end
return dst
end
function table.shallow_copy(t,merge)local copy={}for k,v in pairs(t)do
copy[k]=v
end
if merge then
table.merge(copy,merge)end
return copy
end
function table.keys(t)local keys={}for k,_ in pairs(t)do
keys[#keys+1]=k
end
return keys
end
function table.values(t)local values={}for _,v in pairs(t)do
values[#values+1]=v
end
return values
end
end)()

__mod_rtk_future=(function()
local rtk=__mod_rtk_core
rtk.Future=rtk.class('rtk.Future')rtk.Future.static.PENDING=false
rtk.Future.static.DONE=true
rtk.Future.static.CANCELLED=0
function rtk.Future:initialize()self.state=rtk.Future.PENDING
self.result=nil
self.cancellable=false
end
function rtk.Future:after(func)if not self._after then
self._after={func}else
self._after[#self._after+1]=func
end
self:_check_defer_resolved_callbacks(rtk.Future.DONE)return self
end
function rtk.Future:done(func)if not self._done then
self._done={func}else
self._done[#self._done+1]=func
end
self:_check_defer_resolved_callbacks(rtk.Future.DONE)return self
end
function rtk.Future:cancelled(func)self.cancellable=true
if self.state==rtk.Future.CANCELLED then
func(self.result)elseif not self._cancelled then
self._cancelled={func}else
self._cancelled[#self._cancelled+1]=func
end
return self
end
function rtk.Future:cancel(v)assert(self._cancelled, 'Future is not cancelleable')assert(self.state==rtk.Future.PENDING, 'Future has already been resolved or cancelled')self.state=rtk.Future.CANCELLED
self.result=v
for i=1,#self._cancelled do
self._cancelled[i](v)end
self._cancelled=nil
return self
end
function rtk.Future:_resolve(value)self.result=value
self:_invoke_resolved_callbacks(value)end
function rtk.Future:_check_defer_resolved_callbacks(state,value)if self.state==state and not self._deferred then
self._deferred=true
rtk.defer(rtk.Future._invoke_resolved_callbacks,self,value or self.value)end
end
function rtk.Future:_invoke_resolved_callbacks(value)self._deferred=false
self.result=value
local nextval=value
if self._after then
while #self._after>0 do
local func=table.remove(self._after,1)nextval=func(nextval)or nextval
if rtk.isa(nextval,rtk.Future)then
nextval:done(function(v)self:_resolve(v)end)self:cancelled(function(v)nextval:cancel(v)end)return
end
end
end
self.state=rtk.Future.DONE
if self._done and(not self._after or #self._after==0)then
for i=1,#self._done do
self._done[i](nextval)end
end
self._done=nil
self._after=nil
return self
end
function rtk.Future:resolve(value)assert(self.state==rtk.Future.PENDING, 'Future has already been resolved or cancelled')if not self._after and not self._done and not self._deferred then
self._deferred=true
rtk.defer(self._resolve,self,value,true)else
self:_resolve(value)end
return self
end
end)()

__mod_rtk_animate=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
local c1=1.70158
local c2=c1*1.525
local c3=c1+1
local c4=(2*math.pi)/3
local c5=(2*math.pi)/4.5
local n1=7.5625
local d1=2.75
rtk.easing={['linear'] = function(x)return x
end,['in-sine'] = function(x)return 1-math.cos((x*math.pi)/2)end,['out-sine'] = function(x)return math.sin((x*math.pi)/2)end,['in-out-sine'] = function(x)return-(math.cos(math.pi*x)-1)/2
end,['in-quad'] = function(x)return x*x
end,['out-quad'] = function(x)return 1-(1-x)*(1-x)end,['in-out-quad'] = function(x)return(x<0.5)and(2*x*x)or(1-(-2*x+2)^2/2)end,['in-cubic'] = function(x)return x*x*x
end,['out-cubic'] = function(x)return 1-(1-x)^4
end,['in-out-cubic'] = function(x)return(x<0.5)and(4*x*x*x)or(1-(-2*x+2)^3/2)end,['in-quart'] = function(x)return x*x*x*x
end,['out-quart'] = function(x)return 1-(1-x)^4
end,['in-out-quart'] = function(x)return(x<0.5)and(8*x*x*x*x)or(1-(-2*x+2)^4/2)end,['in-quint'] = function(x)return x*x*x*x*x
end,['out-quint'] = function(x)return 1-(1-x)^5
end,['in-out-quint'] = function(x)return(x<0.5)and(16*x*x*x*x*x)or(1-(-2*x+2)^5/2)end,['in-expo'] = function(x)return(x==0)and 0 or 2^(10*x-10)end,['out-expo'] = function(x)return(x==1)and 1 or(1-2^(-10*x))end,['in-out-expo'] = function(x)return(x==0)and 0 or
(x==1)and 1 or
(x<0.5)and 2^(20*x-10)/2 or(2-2^(-20*x+10))/2
end,['in-circ'] = function(x)return 1-math.sqrt(1-x^2)end,['out-circ'] = function(x)return math.sqrt(1-(x-1)^2)end,['in-out-circ'] = function(x)return(x<0.5)and(1-math.sqrt(1-(2*x)^2))/2 or(math.sqrt(1-(-2*x+2)^2)+1)/2
end,['in-back'] = function(x)return c3*x*x*x-c1*x*x
end,['out-back'] = function(x)return 1+(c3*(x-1)^3)+(c1*(x-1)^2)end,['in-out-back'] = function(x)return(x<0.5)and
((2*x)^2*((c2+1)*2*x-c2))/2 or
((2*x-2)^2*((c2+1)*(x*2-2)+c2)+2)/2
end,['in-elastic'] = function(x)return(x==0)and 0 or
(x==1)and 1 or
-2^(10*x-10)*math.sin((x*10-10.75)*c4)end,['out-elastic'] = function(x)return(x==0)and 0 or
(x==1)and 1 or
2^(-10*x)*math.sin((x*10-0.75)*c4)+1
end,['in-out-elastic'] = function(x)return(x==0)and 0 or
(x==1)and 1 or
(x<0.5)and-(2^(20*x-10)*math.sin((20*x-11.125)*c5))/2 or
(2^(-20*x+10)*math.sin((20*x-11.125)*c5))/2+1
end,['in-bounce'] = function(x)return 1 - rtk.easing['out-bounce'](1 - x)end,['out-bounce'] = function(x)if x<1/d1 then
return n1*x*x
elseif x<(2/d1)then
x=x-1.5/d1
return n1*x*x+0.75
elseif x<(2.5/d1)then
x=x-2.25/d1
return n1*x*x+0.9375
else
x=x-2.625/d1
return n1*x*x+0.984375
end
end,['in-out-bounce'] = function(x)return(x<0.5)and
(1 - rtk.easing['out-bounce'](1 - 2 * x)) / 2 or
(1 + rtk.easing['out-bounce'](2 * x - 1)) / 2
end,}local function _resolve(x,src,dst)return src+x*(dst-src)end
local _table_stepfuncs={[1]=function(widget,anim)local x=anim.easingfunc(anim.pct)return {_resolve(x,anim.src[1],anim.dst[1])}end,[2]=function(widget,anim)local x=anim.easingfunc(anim.pct)local src,dst=anim.src,anim.dst
local f1=_resolve(x,src[1],dst[1])local f2=_resolve(x,src[2],dst[2])return {f1,f2}end,[3]=function(widget,anim)local x=anim.easingfunc(anim.pct)local src,dst=anim.src,anim.dst
local f1=_resolve(x,src[1],dst[1])local f2=_resolve(x,src[2],dst[2])local f3=_resolve(x,src[3],dst[3])return {f1,f2,f3}end,[4]=function(widget,anim)local x=anim.easingfunc(anim.pct)local src,dst=anim.src,anim.dst
local f1=_resolve(x,src[1],dst[1])local f2=_resolve(x,src[2],dst[2])local f3=_resolve(x,src[3],dst[3])local f4=_resolve(x,src[4],dst[4])return {f1,f2,f3,f4}end,any=function(widget,anim)local x=anim.easingfunc(anim.pct)local src,dst=anim.src,anim.dst
local result={}for i=1,#src do
result[i]=_resolve(x,src[i],dst[i])end
return result
end
}function rtk._do_animations(now)if not rtk._frame_times then
rtk._frame_times={now}else
local times=rtk._frame_times
local c=#times
times[c+1]=now
if c>30 then
table.remove(times,1)end
rtk.fps=c/(times[c]-times[1])end
if rtk._animations_len>0 then
local donefuncs=nil
local done=nil
for key,anim in pairs(rtk._animations)do
local widget=anim.widget
local target=anim.target or anim.widget
local attr=anim.attr
local finished=anim.pct>=1.0
local elapsed=now-anim._start_time
local newval,exterior
if anim.stepfunc then
newval,exterior=anim.stepfunc(target,anim)else
newval=anim.resolve(anim.easingfunc(anim.pct))end
anim.frames=anim.frames+1
if not finished and elapsed>anim.duration*1.5 then
log.warning('animation: %s %s - failed to complete within 1.5x of duration (fps: current=%s expected=%s)',target,attr,rtk.fps,anim.startfps)finished=true
end
if anim.update then
anim.update(finished and anim.doneval or newval,target,attr,anim)end
if widget then
if not finished then
local value=newval
if exterior==nil and anim.calculate then
value=anim.calculate(widget,attr,newval,widget.calc)exterior=value
end
widget.calc[attr]=value
if anim.sync_exterior_value then
widget[attr]=exterior or value
end
else
widget:attr(attr,anim.doneval or exterior)end
local reflow=anim.reflow or(anim.attrmeta and anim.attrmeta.reflow)or rtk.Widget.REFLOW_PARTIAL
if reflow and reflow~=rtk.Widget.REFLOW_NONE then
widget:queue_reflow(reflow)end
if anim.attrmeta and anim.attrmeta.window_sync then
widget._sync_window_attrs_on_update=true
end
end
if finished then
rtk._animations[key]=nil
rtk._animations_len=rtk._animations_len-1
if not done then
done={}end
done[#done+1]=anim
else
anim.pct=anim.pct+anim.pctstep
end
end
if done then
for _,anim in ipairs(done)do
anim.future:resolve(anim.widget or anim.target)local took=reaper.time_precise()-anim._start_time
local missed=took-anim.duration
log.log(math.abs(missed)>0.05 and log.DEBUG or log.DEBUG2,'animation: done %s: %s -> %s on %s frames=%s current-fps=%s expected-fps=%s took=%.1f (missed by %.3f)',anim.attr,anim.src,anim.dst,anim.target or anim.widget,anim.frames,rtk.fps,anim.startfps,took,missed
)end
end
return true
end
end
local function _is_equal(a,b)local ta=type(a)if ta~=type(b)then
return false
elseif ta=='table' then
if #a~=#b then
return false
end
for i=1,#a do
if a[i]~=b[i] then
return false
end
end
return true
end
return a==b
end
function rtk.queue_animation(kwargs)assert(kwargs and kwargs.key, 'animation table missing key field')local future=rtk.Future()local key=kwargs.key
local anim=rtk._animations[key]
if anim then
if _is_equal(anim.dst,kwargs.dst)then
return anim.future
else
anim.future:cancel()end
end
if _is_equal(kwargs.src,kwargs.dst)then
future:resolve()return future
end
future:cancelled(function()rtk._animations[key]=nil
rtk._animations_len=rtk._animations_len-1
end)local duration=kwargs.duration or 0.5
local easingfunc=rtk.easing[kwargs.easing or 'linear']
assert(type(easingfunc)=='function', string.format('unknown easing function: %s', kwargs.easing))if not kwargs.stepfunc then
local tp=type(kwargs.src or 0)if tp=='table' then
local sz=#kwargs.src
for i=1,sz do
assert(type(kwargs.src[i])=='number', 'animation src value table must not have non-numeric elements')end
kwargs.stepfunc=_table_stepfuncs[sz]
if not kwargs.stepfunc then
kwargs.stepfunc=_table_stepfuncs.any
end
else
assert(tp=='number', string.format('animation src value %s is invalid', kwargs.src))end
end
if not rtk._animations[kwargs.key] then
rtk._animations_len=rtk._animations_len+1
end
local step=1.0/(rtk.fps*duration)anim=table.shallow_copy(kwargs,{easingfunc=easingfunc,src=kwargs.src or(not kwargs.stepfunc and 0 or nil),dst=kwargs.dst or 0,doneval=kwargs.doneval or kwargs.dst,pct=step,pctstep=step,duration=duration,future=future,frames=0,startfps=rtk.fps,_start_time=reaper.time_precise()})anim.resolve=function(x)return _resolve(x,anim.src,anim.dst)end
rtk._animations[kwargs.key]=anim
log.debug2('animation: scheduled %s', kwargs.key)return future
end
end)()

__mod_rtk_color=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.color={}function rtk.color.set(color,amul)local r,g,b,a=rtk.color.rgba(color)if amul then
a=a*amul
end
gfx.set(r,g,b,a)end
function rtk.color.rgba(color)local tp=type(color)if tp=='table' then
local r,g,b,a=table.unpack(color)return r,g,b,a or 1
elseif tp=='string' then
local hash=color:find('#')if hash==1 then
return rtk.color.hex2rgba(color)else
local a
if hash then
a=(tonumber(color:sub(hash+1),16)or 0)/255
color=color:sub(1,hash-1)end
local resolved=rtk.color.names[color:lower()]
if not resolved then
log.warning('rtk: color "%s" is invalid, defaulting to black', color)return 0,0,0,a or 1
end
local r,g,b,a2=rtk.color.hex2rgba(resolved)return r,g,b,a or a2
end
elseif tp=='number' then
local r,g,b=color&0xff,(color>>8)&0xff,(color>>16)&0xff
return r/255,g/255,b/255,1
else
error('invalid type ' .. tp .. ' passed to rtk.color.rgba()')end
end
function rtk.color.luma(color,under)if not color then
return under and rtk.color.luma(under)or 0
end
local r,g,b,a=rtk.color.rgba(color)local luma=(0.2126*r+0.7152*g+0.0722*b)if a<1.0 then
luma=math.abs((luma*a)+(under and(rtk.color.luma(under)*(1-a))or 0))end
return luma
end
function rtk.color.hsv(color)local r,g,b,a=rtk.color.rgba(color)local h,s,v
local max=math.max(r,g,b)local min=math.min(r,g,b)local delta=max-min
if delta==0 then
h=0
elseif max==r then
h=60*(((g-b)/delta)%6)elseif max==g then
h=60*(((b-r)/delta)+2)elseif max==b then
h=60*(((r-g)/delta)+4)end
s=(max==0)and 0 or(delta/max)v=max
return h/360.0,s,v,a
end
function rtk.color.hsl(color)local r,g,b,a=rtk.color.rgba(color)local h,s,l
local max=math.max(r,g,b)local min=math.min(r,g,b)l=(max+min)/2
if max==min then
h=0
s=0
else
local delta=max-min
if l>0.5 then
s=delta/(2-max-min)else
s=delta/(max+min)end
if max==r then
h=(g-b)/delta+(g<b and 6 or 0)elseif max==g then
h=(b-r)/delta+2
else
h=(r-g)/delta+4
end
h=h/6
end
return h,s,l,a
end
function rtk.color.int(color,native)local r,g,b,_=rtk.color.rgba(color)local n=(r*255)+((g*255)<<8)+((b*255)<<16)return native and rtk.color.convert_native(n)or n
end
function rtk.color.mod(color,hmul,smul,vmul,amul)local h,s,v,a=rtk.color.hsv(color)return rtk.color.hsv2rgb(rtk.clamp(h*(hmul or 1),0,1),rtk.clamp(s*(smul or 1),0,1),rtk.clamp(v*(vmul or 1),0,1),rtk.clamp(a*(amul or 1),0,1))end
function rtk.color.convert_native(n)if rtk.os.mac or rtk.os.linux then
return rtk.color.flip_byte_order(n)else
return n
end
end
function rtk.color.flip_byte_order(color)return((color&0xff)<<16)|(color&0xff00)|((color>>16)&0xff)end
function rtk.color.get_reaper_theme_bg()if reaper.GetThemeColor then
local r=reaper.GetThemeColor('col_tracklistbg', 0)if r~=-1 then
return rtk.color.int2hex(r)end
end
if reaper.GSC_mainwnd then
local idx=(rtk.os.mac or rtk.os.linux)and 5 or 20
return rtk.color.int2hex(reaper.GSC_mainwnd(idx))end
end
function rtk.color.get_icon_style(color,under)return rtk.color.luma(color, under) > rtk.light_luma_threshold and 'dark' or 'light'end
function rtk.color.hex2rgba(s)local r=tonumber(s:sub(2,3),16)or 0
local g=tonumber(s:sub(4,5),16)or 0
local b=tonumber(s:sub(6,7),16)or 0
local a=tonumber(s:sub(8,9),16)return r/255,g/255,b/255,a and a/255 or 1.0
end
function rtk.color.rgba2hex(r,g,b,a)r=math.ceil(r*255)b=math.ceil(b*255)g=math.ceil(g*255)if not a or a==1.0 then
return string.format('#%02x%02x%02x', r, g, b)else
return string.format('#%02x%02x%02x%02x', r, g, b, math.ceil(a * 255))end
end
function rtk.color.int2hex(n,native)if native then
n=rtk.color.convert_native(n)end
local r,g,b=n&0xff,(n>>8)&0xff,(n>>16)&0xff
return string.format('#%02x%02x%02x', r, g, b)end
function rtk.color.hsv2rgb(h,s,v,a)if s==0 then
return v,v,v,a or 1.0
end
local i=math.floor(h*6)local f=(h*6)-i
local p=v*(1-s)local q=v*(1-s*f)local t=v*(1-s*(1-f))if i==0 or i==6 then
return v,t,p,a or 1.0
elseif i==1 then
return q,v,p,a or 1.0
elseif i==2 then
return p,v,t,a or 1.0
elseif i==3 then
return p,q,v,a or 1.0
elseif i==4 then
return t,p,v,a or 1.0
elseif i==5 then
return v,p,q,a or 1.0
else
log.error('invalid hsv (%s %s %s) i=%s', h, s, v, i)end
end
local function hue2rgb(p,q,t)if t<0 then
t=t+1
elseif t>1 then
t=t-1
end
if t<1/6 then
return p+(q-p)*6*t
elseif t<1/2 then
return q
elseif t<2/3 then
return p+(q-p)*(2/3-t)*6
else
return p
end
end
function rtk.color.hsl2rgb(h,s,l,a)local r,g,b
if s==0 then
r,g,b=l,l,l
else
local q=(l<0.5)and(l*(1+s))or(l+s-l*s)local p=2*l-q
r=hue2rgb(p,q,h+1/3)g=hue2rgb(p,q,h)b=hue2rgb(p,q,h-1/3)end
return r,g,b,a or 1.0
end
rtk.color.names={transparent="#ffffff00",black='#000000',silver='#c0c0c0',gray='#808080',white='#ffffff',maroon='#800000',red='#ff0000',purple='#800080',fuchsia='#ff00ff',green='#008000',lime='#00ff00',olive='#808000',yellow='#ffff00',navy='#000080',blue='#0000ff',teal='#008080',aqua='#00ffff',orange='#ffa500',aliceblue='#f0f8ff',antiquewhite='#faebd7',aquamarine='#7fffd4',azure='#f0ffff',beige='#f5f5dc',bisque='#ffe4c4',blanchedalmond='#ffebcd',blueviolet='#8a2be2',brown='#a52a2a',burlywood='#deb887',cadetblue='#5f9ea0',chartreuse='#7fff00',chocolate='#d2691e',coral='#ff7f50',cornflowerblue='#6495ed',cornsilk='#fff8dc',crimson='#dc143c',cyan='#00ffff',darkblue='#00008b',darkcyan='#008b8b',darkgoldenrod='#b8860b',darkgray='#a9a9a9',darkgreen='#006400',darkgrey='#a9a9a9',darkkhaki='#bdb76b',darkmagenta='#8b008b',darkolivegreen='#556b2f',darkorange='#ff8c00',darkorchid='#9932cc',darkred='#8b0000',darksalmon='#e9967a',darkseagreen='#8fbc8f',darkslateblue='#483d8b',darkslategray='#2f4f4f',darkslategrey='#2f4f4f',darkturquoise='#00ced1',darkviolet='#9400d3',deeppink='#ff1493',deepskyblue='#00bfff',dimgray='#696969',dimgrey='#696969',dodgerblue='#1e90ff',firebrick='#b22222',floralwhite='#fffaf0',forestgreen='#228b22',gainsboro='#dcdcdc',ghostwhite='#f8f8ff',gold='#ffd700',goldenrod='#daa520',greenyellow='#adff2f',grey='#808080',honeydew='#f0fff0',hotpink='#ff69b4',indianred='#cd5c5c',indigo='#4b0082',ivory='#fffff0',khaki='#f0e68c',lavender='#e6e6fa',lavenderblush='#fff0f5',lawngreen='#7cfc00',lemonchiffon='#fffacd',lightblue='#add8e6',lightcoral='#f08080',lightcyan='#e0ffff',lightgoldenrodyellow='#fafad2',lightgray='#d3d3d3',lightgreen='#90ee90',lightgrey='#d3d3d3',lightpink='#ffb6c1',lightsalmon='#ffa07a',lightseagreen='#20b2aa',lightskyblue='#87cefa',lightslategray='#778899',lightslategrey='#778899',lightsteelblue='#b0c4de',lightyellow='#ffffe0',limegreen='#32cd32',linen='#faf0e6',magenta='#ff00ff',mediumaquamarine='#66cdaa',mediumblue='#0000cd',mediumorchid='#ba55d3',mediumpurple='#9370db',mediumseagreen='#3cb371',mediumslateblue='#7b68ee',mediumspringgreen='#00fa9a',mediumturquoise='#48d1cc',mediumvioletred='#c71585',midnightblue='#191970',mintcream='#f5fffa',mistyrose='#ffe4e1',moccasin='#ffe4b5',navajowhite='#ffdead',oldlace='#fdf5e6',olivedrab='#6b8e23',orangered='#ff4500',orchid='#da70d6',palegoldenrod='#eee8aa',palegreen='#98fb98',paleturquoise='#afeeee',palevioletred='#db7093',papayawhip='#ffefd5',peachpuff='#ffdab9',peru='#cd853f',pink='#ffc0cb',plum='#dda0dd',powderblue='#b0e0e6',rosybrown='#bc8f8f',royalblue='#4169e1',saddlebrown='#8b4513',salmon='#fa8072',sandybrown='#f4a460',seagreen='#2e8b57',seashell='#fff5ee',sienna='#a0522d',skyblue='#87ceeb',slateblue='#6a5acd',slategray='#708090',slategrey='#708090',snow='#fffafa',springgreen='#00ff7f',steelblue='#4682b4',tan='#d2b48c',thistle='#d8bfd8',tomato='#ff6347',turquoise='#40e0d0',violet='#ee82ee',wheat='#f5deb3',whitesmoke='#f5f5f5',yellowgreen='#9acd32',rebeccapurple='#663399',}end)()
__mod_rtk_font=(function()
local rtk=__mod_rtk_core
local _fontcache={}local _idmgr=rtk.IndexManager(2,127)rtk.Font=rtk.class('rtk.Font')rtk.Font.register{name=nil,size=nil,scale=nil,flags=nil,texth=nil,}function rtk.Font:initialize(name,size,scale,flags)if size then
self:set(name,size,scale,flags)end
end
function rtk.Font:finalize()if self._idx then
self:_decref()end
end
function rtk.Font:_decref()if not self._idx or self._idx==1 then
return
end
local refcount=_fontcache[self._key][2]
if refcount<=1 then
_idmgr:release(self._idx)_fontcache[self._key]=nil
else
_fontcache[self._key][2]=refcount-1
end
end
function rtk.Font:_get_id()local idx=_idmgr:next(true)if idx then
return idx
end
return 1
end
function rtk.Font:draw(text,x,y,clipw,cliph,flags)if rtk.os.mac then
local fudge=math.ceil(1*rtk.scale.value)y=y+fudge
if cliph then
cliph=cliph-fudge
end
end
flags=flags or 0
self:set()if type(text)=='string' then
gfx.x=x
gfx.y=y
if cliph then
gfx.drawstr(text,flags,x+clipw,y+cliph)else
gfx.drawstr(text,flags)end
elseif #text==1 then
local segment,sx,sy,sw,sh=table.unpack(text[1])gfx.x=x+sx
gfx.y=y+sy
if cliph then
gfx.drawstr(segment,flags,x+clipw,y+cliph)else
gfx.drawstr(segment,flags)end
else
flags=flags|(cliph and 0 or 256)local checkh=cliph
clipw=x+(clipw or 0)cliph=y+(cliph or 0)for n=1,#text do
local segment,sx,sy,sw,sh=table.unpack(text[n])local offy=y+sy
if checkh and offy>cliph then
break
elseif offy+sh>=0 then
gfx.x=x+sx
gfx.y=offy
gfx.drawstr(segment,flags,clipw,cliph)end
end
end
end
function rtk.Font:measure(s)self:set()return gfx.measurestr(s)end
local _wrap_characters={[' '] = true,['-'] = true,[','] = true,['.'] = true,['!'] = true,['?'] = true,['\n'] = true,['/'] = true,['\\'] = true,[';'] = true,[':'] = true,}function rtk.Font:layout(text,boxw,boxh,wrap,align,relative,spacing,breakword)self:set()local segments={text=text,boxw=boxw,boxh=boxh,wrap=wrap,align=align,relative=relative,spacing=spacing,multiplier=rtk.font.multiplier,scale=rtk.scale.value,dirty=false,isvalid=function()return not self.dirty and self.scale==rtk.scale.value and self.multiplier==rtk.font.multiplier
end
}align=align or rtk.Widget.LEFT
spacing=(spacing or 0)+math.ceil((rtk.os.mac and 3 or 0)*rtk.scale.value)if not text:find('\n') then
local w,h=gfx.measurestr(text)if w<=boxw or not wrap then
segments[1]={text,0,0,w,h}return segments,w,h
end
end
local maxwidth=0
local y=0
local function addsegment(segment)local w,h=gfx.measurestr(segment)segments[#segments+1]={segment,0,y,w,h}maxwidth=math.max(w,maxwidth)y=y+h+spacing
end
if not wrap then
for n, line in ipairs(text:split('\n')) do
if #line>0 then
addsegment(line)else
y=y+self.texth+spacing
end
end
else
local startpos=1
local wrappos=1
local len=text:len()for endpos=1,len do
local substr=text:sub(startpos,endpos)local ch=text:sub(endpos,endpos)local w,h=gfx.measurestr(substr)if _wrap_characters[ch] then
wrappos=endpos
end
if w > boxw or ch=='\n' then
local wrapchar=_wrap_characters[text:sub(wrappos,wrappos)]
if breakword and(wrappos==startpos or not wrapchar)then
wrappos=endpos-1
end
if wrappos>startpos and(breakword or wrapchar)then
addsegment(text:sub(startpos,wrappos):strip())startpos=wrappos+1
wrappos=endpos
elseif ch=='\n' then
y=y+self.texth+spacing
end
end
end
if startpos<=len then
addsegment(string.strip(text:sub(startpos,len)))end
end
if align==rtk.Widget.CENTER then
maxwidth=relative and maxwidth or boxw
for n,segment in ipairs(segments)do
segment[2]=(maxwidth-segment[4])/2
end
end
if align==rtk.Widget.RIGHT then
maxwidth=relative and maxwidth or boxw
for n,segment in ipairs(segments)do
segment[2]=maxwidth-segment[4]
end
end
return segments,maxwidth,y
end
function rtk.Font:set(name,size,scale,flags)local global_scale=rtk.scale.value
if not size and self._last_global_scale~=global_scale then
name=name or self.name
size=self.size
scale=scale or self.scale
flags=flags or self.flags
else
scale=scale or 1
flags=flags or 0
end
local sz=size and math.ceil(size*scale*global_scale*rtk.font.multiplier)local newfont=name and(name~=self.name or sz~=self.calcsize or flags~=self.flags)if self._idx and self._idx>1 then
if not newfont then
gfx.setfont(self._idx)return false
else
self:_decref()end
elseif self._idx==1 then
gfx.setfont(1,self.name,self.calcsize,self.flags)return true
end
if not newfont then
error('rtk.Font:set() called without arguments and no font parameters previously set')end
local key=name..tostring(sz)..tostring(flags)local cache=_fontcache[key]
local idx
if not cache then
idx=self:_get_id()if idx>1 then
_fontcache[key]={idx,1}end
else
cache[2]=cache[2]+1
idx=cache[1]
end
gfx.setfont(idx,name,sz,flags)self._key=key
self._idx=idx
self._last_global_scale=global_scale
self.name=name
self.size=size
self.scale=scale
self.flags=flags
self.calcsize=sz
self.texth=gfx.texth
return true
end
end)()

__mod_rtk_event=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Event=rtk.class('rtk.Event')rtk.Event.static.MOUSEDOWN=1
rtk.Event.static.MOUSEUP=2
rtk.Event.static.MOUSEMOVE=3
rtk.Event.static.MOUSEWHEEL=4
rtk.Event.static.KEY=5
rtk.Event.static.DROPFILE=6
rtk.Event.static.WINDOWCLOSE=7
rtk.Event.static.typenames={[rtk.Event.MOUSEDOWN]='mousedown',[rtk.Event.MOUSEUP]='mouseup',[rtk.Event.MOUSEMOVE]='mousemove',[rtk.Event.MOUSEWHEEL]='mousewheel',[rtk.Event.KEY]='key',[rtk.Event.DROPFILE]='dropfile',[rtk.Event.WINDOWCLOSE]='windowclose',}rtk.Event.register{type=nil,handled=nil,button=0,buttons=0,wheel=0,hwheel=0,char=nil,keycode=nil,keynorm=nil,ctrl=false,shift=false,alt=false,meta=false,modifiers=nil,files=nil,x=nil,y=nil,time=0,tick=nil,simulated=nil,debug=nil,}function rtk.Event:initialize(attrs)self:reset()if attrs then
table.merge(self,attrs)end
end
function rtk.Event:__tostring()local custom
if self.type>=1 and self.type<=3 then
custom = string.format(' button=%s buttons=%s', self.button, self.buttons)elseif self.type==4 then
custom = string.format(' wheel=%s,%s', self.hwheel, self.wheel)elseif self.type==5 then
custom = string.format(' char=%s keycode=%s', self.char, self.keycode)elseif self.type==6 then
custom=' ' .. table.tostring(self.files)end
return string.format('Event<%s xy=%s,%s handled=%s sim=%s%s>',rtk.Event.typenames[self.type] or 'unknown',self.x,self.y,self.handled,self.simulated,custom or '')end
function rtk.Event:reset(type)table.merge(self,self.class.attributes.defaults)self.type=type
self.handled=nil
self.debug=nil
self.files=nil
self.simulated=nil
self.time=nil
self.char=nil
self.x=gfx.mouse_x
self.y=gfx.mouse_y
self.tick=rtk.tick
return self
end
function rtk.Event:is_mouse_event()return self.type<=rtk.Event.MOUSEWHEEL
end
function rtk.Event:get_button_duration(button)local buttonstate=rtk.mouse.state[button or self.button]
if buttonstate then
return self.time-buttonstate.time
end
end
function rtk.Event:set_widget_mouseover(widget)if rtk.debug and not self.debug then
self.debug=widget
end
if widget.calc.tooltip and not rtk._mouseover_widget and self.type==rtk.Event.MOUSEMOVE and not self.simulated then
rtk._mouseover_widget=widget
end
end
function rtk.Event:set_widget_pressed(widget)if not rtk._pressed_widgets then
rtk._pressed_widgets={order={}}end
table.insert(rtk._pressed_widgets.order,widget)rtk._pressed_widgets[widget.id]={self.x,self.y,self.time}if not rtk._drag_candidates then
rtk._drag_candidates={}end
table.insert(rtk._drag_candidates,{widget,false})end
function rtk.Event:is_widget_pressed(widget)return rtk._pressed_widgets and rtk._pressed_widgets[widget.id] and true or false
end
function rtk.Event:set_button_state(key,value)rtk.mouse.state[self.button][key]=value
end
function rtk.Event:get_button_state(key)local s=rtk.mouse.state[self.button]
return s and s[key]
end
function rtk.Event:set_modifiers(cap,button)self.modifiers=cap&(4|8|16|32)self.ctrl=cap&4~=0
self.shift=cap&8~=0
self.alt=cap&16~=0
self.meta=cap&32~=0
self.buttons=cap&(1|2|64)self.button=button
end
local keynorm_map={[33]=49,[64]=50,[35]=51,[36]=52,[37]=53,[94]=54,[38]=55,[42]=56,[40]=57,[41]=48,[126]=96,[95]=45,[43]=61,[123]=91,[125]=93,[58]=59,[34]=39,[60]=44,[62]=46,[63]=47,}function rtk.Event:set_keycode(keycode)self.keycode=math.ceil(keycode)self.keynorm=keycode
if keycode<=26 and self.ctrl then
self.keynorm=keycode+96
self.char=string.char(self.keynorm)elseif keycode>=65 and keycode<=90 then
self.keynorm=keycode+32
self.char=string.char(keycode)elseif keycode>=32 and keycode~=127 then
if keycode<=255 then
self.keynorm=keynorm_map[keycode] or self.keycode
self.char=string.char(self.keycode)elseif keycode<=282 then
self.keynorm=keycode-160
self.char=string.char(self.keynorm)elseif keycode<=346 then
self.keynorm=keycode-224
self.char=string.char(self.keynorm)end
end
end
function rtk.Event:set_handled(widget)self.handled=widget or true
end
function rtk.Event:clone(overrides)local event=rtk.Event()for k,v in pairs(self)do
event[k]=v
end
event.handled=nil
event.tick=rtk.tick
table.merge(event,overrides or {})return event
end
end)()

__mod_rtk_image=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Image=rtk.class('rtk.Image')rtk.Image.static._icons={}rtk.Image.static.DEFAULT=0
rtk.Image.static.ADDITIVE_BLEND=1
rtk.Image.static.SUBTRACTIVE_BLEND=128
rtk.Image.static.NO_SOURCE_ALPHA=2
rtk.Image.static.NO_FILTERING=4
rtk.Image.static.FAST_BLIT=2|4
rtk.Image.static.ids=rtk.IndexManager(0,1023)local function _search_image_paths_list(id,fname,paths)if not paths or #paths==0 then
return
end
local path=paths[1]..fname
local r=gfx.loadimg(id,path)if r~=-1 then
return path
end
if #paths>1 then
for i=2,#paths do
path=paths[i]..fname
r=gfx.loadimg(id,path)if r~=-1 then
return path
end
end
end
end
function rtk.Image.static._search_image_paths_nostyle(id,fname)local path=_search_image_paths_list(id,fname,rtk._image_paths.nostyle)return path or _search_image_paths_list(id,fname,rtk._image_paths.fallback)end
function rtk.Image.static._search_image_paths_style(id,fname,style)local path=_search_image_paths_list(id,fname,rtk._image_paths[style])if path then
return path,style
end
end
function rtk.Image.static._search_image_paths(id,fname,style)local path,gotstyle
if not style then
path,gotstyle=rtk.Image._search_image_paths_nostyle(id,fname)if not path then
style=rtk.theme.iconstyle
path,gotstyle=rtk.Image._search_image_paths_style(id,fname,style)end
else
path,gotstyle=rtk.Image._search_image_paths_style(id,fname,style)if not path then
path,gotstyle=rtk.Image._search_image_paths_nostyle(id,fname)end
end
if not path then
local other=(style=='light') and 'dark' or 'light'path,gotstyle=rtk.Image._search_image_paths_style(id,fname,other)end
return path,gotstyle
end
function rtk.Image.static.icon(name,style)style=style or rtk.theme.iconstyle
local pack=rtk.Image._icons[name]
if pack then
local img=pack:get(name,style)if img then
return img
end
end
if not name:find('%.[%w_]+$') then
name=name .. '.png'end
local img,gotstyle=rtk.Image():_load(name,style)if img then
if gotstyle and gotstyle~=style then
img:recolor(style=='light' and '#ffffff' or '#000000')end
img.style=style
end
if not img then
log.error('rtk: rtk.Image.icon("%s"): icon could not be loaded from any image path', name)end
return img
end
rtk.Image.static.make_icon=rtk.Image.static.icon
function rtk.Image.static.make_placeholder_icon(w,h,style)local img=rtk.Image(w or 24,h or 24)img:pushdest()rtk.color.set({1,0.2,0.2,1})gfx.setfont(1, 'Sans', w or 24)gfx.x,gfx.y=5,0
gfx.drawstr('?')img:popdest()img.style=style or 'dark'return img
end
rtk.Image.register{x=0,y=0,w=nil,h=nil,density=1.0,path=nil,rotation=0,id=nil,}function rtk.Image:initialize(w,h,density)table.merge(self,self.class.attributes.defaults)if h then
self:create(w,h,density)end
end
function rtk.Image:finalize()if self.id and not self._ref then
gfx.setimgdim(self.id,0,0)rtk.Image.static.ids:release(self.id)end
end
function rtk.Image:__tostring()local clsname=self.class.name:gsub('rtk.', '')return string.format('<%s %s,%s %sx%s id=%s density=%s path=%s ref=%s>',clsname,self.x,self.y,self.w,self.h,self.id,self.density,self.path,self._ref
)end
function rtk.Image:create(w,h,density)if not self.id then
self.id=rtk.Image.static.ids:next(true)if not self.id then
error("unable to allocate image: ran out of available REAPER image buffers")end
end
if h~=nil then
self:resize(w,h,false)end
self.density=density or 1.0
return self
end
function rtk.Image:load(path,density)local ok,gotstyle=self:_load(path,nil,density)if ok then
return self
else
log.warning('rtk: rtk.Image:load("%s"): no such file found in any search paths', path)end
end
function rtk.Image:_load(fname,style,density)local id=self.id
if not id or self._ref then
id=rtk.Image.static.ids:next()end
local path,gotstyle=rtk.Image._search_image_paths(id,fname,style)if path then
self.id=id
self.path=path
self.w,self.h=gfx.getimgdim(id)self.density=density or 1.0
return self,gotstyle
else
rtk.Image.static.ids:release(id)self.w,self.h=nil,nil
self.id=nil
end
end
function rtk.Image:pushdest()assert(self.id, 'create() or load() must be called first')rtk.pushdest(self.id)end
function rtk.Image:popdest()assert(gfx.dest==self.id, 'rtk.Image.popdest() called on image that is not the current drawing target')rtk.popdest()end
function rtk.Image:clone()local newimg=rtk.Image(self.w,self.h)if self.id then
newimg:blit{src=self,sx=self.x,sy=self.y}end
newimg.density=self.density
return newimg
end
function rtk.Image:resize(w,h,clear)w=math.ceil(w)h=math.ceil(h)if self.w~=w or self.h~=h then
if not self.id then
return self:create(w,h)end
self.w,self.h=w,h
gfx.setimgdim(self.id,0,0)gfx.setimgdim(self.id,w,h)end
if clear~=false then
self:clear()end
return self
end
function rtk.Image:scale(w,h,mode,density)assert(w or h, 'one or both of w or h parameters must be specified')if not self.id then
return rtk.Image(w,h)end
local aspect=self.w/self.h
w=w or(h/aspect)h=h or(w*aspect)local newimg=rtk.Image(w,h)newimg:blit{src=self,sx=self.x,sy=self.y,sw=self.w,sh=self.h,dw=newimg.w,dh=newimg.h,mode=mode}newimg.density=density or self.density
return newimg
end
function rtk.Image:clear(color)self:pushdest()if not color then
gfx.set(0,0,0,0,rtk.Image.DEFAULT,self.id,0)gfx.setimgdim(self.id,0,0)gfx.setimgdim(self.id,self.w,self.h)else
rtk.color.set(color)gfx.mode=rtk.Image.DEFAULT
end
gfx.rect(self.x,self.y,self.w,self.h,1)gfx.set(0,0,0,1,rtk.Image.DEFAULT,self.id,1)self:popdest()return self
end
function rtk.Image:viewport(x,y,w,h,density)local new=rtk.Image()new.id=self.id
new.density=density or self.density
new.path=self.path
new.x=x or 0
new.y=y or 0
new.w=w or(self.w-new.x)new.h=h or(self.h-new.y)new._ref=self
return new
end
function rtk.Image:draw(dx,dy,a,scale,clipw,cliph,mode)return self:blit{dx=dx,dy=dy,alpha=a,clipw=clipw,cliph=cliph,mode=mode,scale=scale
}end
function rtk.Image:blit(attrs)attrs=attrs or {}gfx.a=attrs.alpha or 1.0
local mode=attrs.mode or rtk.Image.DEFAULT
if mode&rtk.Image.SUBTRACTIVE_BLEND~=0 then
mode=(mode&~rtk.Image.SUBTRACTIVE_BLEND)|rtk.Image.ADDITIVE_BLEND
gfx.a=-gfx.a
end
gfx.mode=mode
local src=attrs.src
if src and type(src)=='table' then
assert(rtk.isa(src, rtk.Image), 'src must be an rtk.Image or numeric image id')src=src.id
end
if src then
self:pushdest()end
local scale=(attrs.scale or 1.0)/self.density
local sx=attrs.sx or self.x
local sy=attrs.sy or self.y
local sw=attrs.sw or self.w
local sh=attrs.sh or self.h
local dx=attrs.dx or 0
local dy=attrs.dy or 0
local dw=attrs.dw or(sw*scale)local dh=attrs.dh or(sh*scale)local rotation=attrs.rotation and math.rad(attrs.rotation)or self._rotation_rads
if attrs.clipw and dw>attrs.clipw then
sw=sw-(dw-attrs.clipw)/(dw/sw)dw=attrs.clipw
end
if attrs.cliph and dh>attrs.cliph then
sh=sh-(dh-attrs.cliph)/(dh/sh)dh=attrs.cliph
end
if rotation==0 or not rotation then
gfx.blit(src or self.id,1.0,0,sx,sy,sw,sh,dx or 0,dy or 0,dw,dh,0,0)else
gfx.blit(src or self.id,1.0,rotation,sx-(self._soffx or 0),sy-(self._soffy or 0),self._dw,self._dh,dx-(self._doffx or 0),dy-(self._doffy or 0),self._dw,self._dh,0,0
)end
gfx.mode=0
if src then
self:popdest()end
return self
end
function rtk.Image:recolor(color)local r,g,b,_=rtk.color.rgba(color)return self:filter(0,0,0,1.0,r,g,b,0)end
function rtk.Image:filter(mr,mg,mb,ma,ar,ag,ab,aa)self:pushdest()gfx.muladdrect(self.x,self.y,self.w,self.h,mr,mg,mb,ma,ar,ag,ab,aa)self:popdest()return self
end
function rtk.Image:rect(color,x,y,w,h,fill)self:pushdest()rtk.color.set(color)gfx.rect(x,y,w,h,fill)self:popdest()return self
end
function rtk.Image:blur(strength,x,y,w,h)if not self.w then
return self
end
self:pushdest()gfx.mode=6
x=x or 0
y=y or 0
for i=1,strength or 20 do
gfx.x=x
gfx.y=y
gfx.blurto(x+(w or self.w),y+(h or self.h))end
self:popdest()return self
end
function rtk.Image:flip_vertical()self:pushdest()gfx.mode=6
gfx.a=1
gfx.transformblit(self.id,self.x,self.y,self.w,self.h,2,2,{self.x,self.y+self.h,self.x+self.w,self.y+self.h,self.x,self.y,self.x+self.w,self.y
})rtk.popdest()return self
end
local function _xlate(x,y,theta)return x*math.cos(theta)-y*math.sin(theta),x*math.sin(theta)+y*math.cos(theta)end
function rtk.Image:rotate(degrees)self.rotation=degrees
local rads=math.rad(degrees)self._rotation_rads=rads
local x1,y1=0,0
local xt1,yt1=_xlate(x1,y1,rads)local x2,y2=0+self.w,0
local xt2,yt2=_xlate(x2,y2,rads)local x3,y3=0,self.h
local xt3,yt3=_xlate(x3,y3,rads)local x4,y4=0+self.w,self.h
local xt4,yt4=_xlate(x4,y4,rads)local xmin=math.min(xt1,xt2,xt3,xt4)local xmax=math.max(xt1,xt2,xt3,xt4)local ymin=math.min(yt1,yt2,yt3,yt4)local ymax=math.max(yt1,yt2,yt3,yt4)local dw=xmax-xmin
local dh=ymax-ymin
local dmax=math.max(dw,dh)self._dw=dmax
self._dh=dmax
self._soffx=(dmax-self.w)/2
self._soffy=(dmax-self.h)/2
self._doffx=math.max(0,(dh-dw)/2)self._doffy=math.max(0,(dw-dh)/2)return self
end
function rtk.Image:refresh_scale()end
end)()

__mod_rtk_multiimage=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.MultiImage=rtk.class('rtk.MultiImage', rtk.Image)function rtk.MultiImage:initialize(...)rtk.Image.initialize(self)self._variants={}local images={...}for _,img in ipairs(images)do
self:add(img)end
end
function rtk.MultiImage:finalize()end
function rtk.MultiImage:add(path_or_image,density)local img
if rtk.isa(path_or_image,rtk.Image)then
assert(not rtk.isa(path_or_image, rtk.MultiImage), 'cannot add an rtk.MultiImage to an rtk.MultiImage')img=path_or_image
else
assert(density, 'density must be supplied when path is passed to add()')img=rtk.Image:load(path_or_image,density)end
assert(not self._variants[img.density], 'replacing existing density not supported')self._variants[img.density]=img
if not self.id or self.density==img.density then
self:_set(img)end
if not self._max or img.density>self._max.density then
self._max=img
end
return img
end
function rtk.MultiImage:load(path,density)if self:add(path,density)then
return self
end
end
function rtk.MultiImage:_set(img)self.current=img
self.id=img.id
self.x=img.x
self.y=img.y
self.w=img.w
self.h=img.h
self.density=img.density
self.path=img.path
self.rotation=img.rotation
end
function rtk.MultiImage:refresh_scale(scale)local best=self._max
scale=scale or rtk.scale.value
for density,img in pairs(self._variants)do
if density==scale then
best=img
break
elseif density>scale and density<best.density then
best=img
end
end
self:_set(best)return self
end
function rtk.MultiImage:clone()local new=rtk.MultiImage()for density,img in pairs(self._variants)do
new:add(img:clone())end
new:_set(new._variants[self.density])return new
end
function rtk.MultiImage:resize(w,h,clear)for density,img in pairs(self._variants)do
img:resize(w*density,h*density,clear)end
self:_set(self.current)return self
end
function rtk.MultiImage:scale(w,h,mode)local new=rtk.MultiImage()for density,img in pairs(self._variants)do
new:add(img:scale(w and w*density,h and h*density,mode))end
new:_set(new._variants[self.density])return new
end
function rtk.MultiImage:clear(color)for density,img in pairs(self._variants)do
img:clear(color)end
end
function rtk.MultiImage:viewport(x,y,w,h)local new=rtk.MultiImage()for density,img in pairs(self._variants)do
new:add(img:viewport(x*density,y*density,w*density,h*density))end
new:_set(new._variants[self.density])return new
end
function rtk.MultiImage:filter(mr,mg,mb,ma,ar,ag,ab,aa)for density,img in pairs(self._variants)do
img:filter(mr,mg,mb,ma,ar,ag,ab,aa)end
return self
end
function rtk.MultiImage:rect(color,x,y,w,h,fill)for density,img in pairs(self._variants)do
img:rect(color,x*density,y*density,w*density,h*density,fill)end
return self
end
function rtk.MultiImage:blur(strength,x,y,w,h)for density,img in pairs(self._variants)do
img:blur(strength,x*density,y*density,w*density,h*density)end
return self
end
function rtk.MultiImage:flip_vertical()for density,img in pairs(self._variants)do
img:flip_vertical()end
return self
end
function rtk.MultiImage:rotate(degrees)for density,img in pairs(self._variants)do
img:rotate(degrees)end
return self
end
end)()

__mod_rtk_imagepack=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.ImagePack=rtk.class('rtk.ImagePack')rtk.ImagePack.register{default_size='medium',}function rtk.ImagePack:initialize(attrs)table.merge(self,self.class.attributes.defaults)self._last_id=0
self._sources={}self._regions={}self._cache={}if attrs then
self.default_size=attrs.default_size or self.default_size
if attrs.src then
self:add(attrs)if attrs.register then
self:register_as_icons()end
end
end
end
function rtk.ImagePack:add(attrs)assert(type(attrs)=='table', 'ImagePack:add() expects a table')assert(type(attrs.src)=='string' or rtk.isa(attrs.src, rtk.Image), '"src" field is missing or is not string or rtk.Image')assert(not attrs.strips or type(attrs.strips)=='table', '"strips" field must be a table')local strips=attrs.strips or attrs
assert(#strips > 0, 'no strips provided (either as a "strips" field or as positional elements elements)')local src_idx=#self._sources+1
self._sources[src_idx]={src=attrs.src,recolors={}}local y=0
for _,strip in ipairs(strips)do
assert(type(strip)=='table', 'ImagePack strip definition must be a table')assert(type(strip.w) == 'number' or type(strip.h) == 'number', 'ImagePack strip requires either "w" or "h" fields')local names=strip.names or attrs.names
assert(type(names)=='table', 'ImagePack strip missing "names" field or is not table')local sizes=strip.sizes
if not sizes then
local density=strip.density or attrs.density or 1
if strip.size then
sizes={{strip.size,density}}elseif attrs.sizes then
sizes=attrs.sizes
elseif attrs.size then
sizes={{attrs.size,density}}else
sizes={{self.default_size,density}}end
end
strip.w=strip.w or strip.h
strip.h=strip.h or strip.w
local columns=strip.columns or attrs.columns
local rowwidth=columns and(columns*strip.w)local style=strip.style or attrs.style
local x=0
for _,name in ipairs(names)do
local subregion={id=self._last_id,src_idx=src_idx,x=x,y=y,w=strip.w,h=strip.h,}self._last_id=self._last_id+1
for _,sizedensity in ipairs(sizes)do
local size,density=table.unpack(sizedensity)local key=string.format('%s:%s:%s', style, name, size)local densities=self._regions[key]
if not densities then
densities={}self._regions[key]=densities
elseif densities[density] then
error(string.format('duplicate image name "%s" for style=%s size=%s density=%s',name,style,size,density
))end
densities[density]=subregion
end
x=x+strip.w
if rowwidth and x>=rowwidth then
x=0
y=y+strip.h
end
end
y=y+strip.h
end
return self
end
function rtk.ImagePack:_get_densities(name,style)local key
if not name:find(':') then
key=string.format('%s:%s:%s', style, name, self.default_size)else
key=string.format('%s:%s', style, name)end
return key,self._regions[key]
end
function rtk.ImagePack:get(name,style)if not name then
return
end
local key,densities=self:_get_densities(name,style)local multi=self._cache[key]
if multi then
return multi
end
local recolor=false
if not densities and not style then
style=rtk.theme.iconstyle
densities=self:_get_densities(name,style)end
if not densities and style then
local otherstyle=style=='light' and 'dark' or 'light'recolor=true
_,densities=self:_get_densities(name,otherstyle)if not densities then
_,densities=self:_get_densities(name,nil)recolor=false
end
end
if not densities then
return
end
local multi=rtk.MultiImage()for density,region in pairs(densities)do
local src=self._sources[region.src_idx]
local img=src.img
if not img then
img=rtk.Image():load(src.src)src.img=img
end
if recolor then
img=src.recolors[style]
if not img then
img=src.img:clone():recolor(style=='light' and '#ffffff' or '#000000')src.recolors[style]=img
end
end
assert(img, string.format('could not read "%s"', src.src))multi:add(img:viewport(region.x,region.y,region.w,region.h,density))end
multi.style=style
self._cache[key]=multi
return multi
end
function rtk.ImagePack:register_as_icons()local default_size=self.default_size
for key,_ in pairs(self._regions)do
local idx=key:find(':')local name=key:sub(idx+1)rtk.Image._icons[name]=self
idx=name:find(':')local size=name:sub(idx+1)if size==default_size then
name=name:sub(1,idx-1)rtk.Image._icons[name]=self
end
end
return self
end
end)()

__mod_rtk_shadow=(function()
local rtk=__mod_rtk_core
rtk.Shadow=rtk.class('rtk.Shadow')rtk.Shadow.static.RECTANGLE=0
rtk.Shadow.static.CIRCLE=1
rtk.Shadow.register{type=nil,color='#00000055',w=nil,h=nil,radius=nil,elevation=nil,}function rtk.Shadow:initialize(color)self.color=color or self.class.attributes.color.default
self._image=nil
self._last_draw_params=nil
end
function rtk.Shadow:set_rectangle(w,h,elevation,t,r,b,l)self.type=rtk.Shadow.RECTANGLE
self.w=w
self.h=h
self.tt=t or elevation
self.tr=r or elevation
self.tb=b or elevation
self.tl=l or elevation
assert(self.tt or self.tr or self.tb or self.tl, 'missing elevation for at least one edge')self.elevation=elevation or math.max(self.tt,self.tr,self.tb,self.tl)self.radius=nil
self._check_generate=true
end
function rtk.Shadow:set_circle(radius,elevation)self.type=rtk.Shadow.CIRCLE
elevation=elevation or radius/1.5
if self.radius==radius and self.elevation==elevation then
return
end
self.radius=radius
self.elevation=elevation
self._check_generate=true
end
function rtk.Shadow:draw(x,y,alpha)if self.radius then
self:_draw_circle(x,y,alpha or 1.0)else
self:_draw_rectangle(x,y,alpha or 1.0)end
end
function rtk.Shadow:_needs_generate()if self._check_generate==false then
return false
end
local params=self._last_draw_params
local gen=not params or
self.w~=params.w or
self.h~=params.h or
self.tt~=params.tt or
self.tr~=params.tr or
self.tb~=params.tb or
self.tl~=params.tl or
self.elevation~=params.elevation or
self.radius~=params.radius
if gen then
self._last_draw_params={w=self.w,h=self.h,tt=self.tt,tr=self.tr,tb=self.tb,tl=self.tl,elevation=self.elevation,radius=self.radius
}end
self._check_generate=false
return gen
end
function rtk.Shadow:_draw_circle(x,y,alpha)local pad=self.elevation*3
if self:_needs_generate()then
local radius=math.ceil(self.radius)local sz=(radius+2+pad)*2
if not self._image then
self._image=rtk.Image(sz,sz)else
self._image:resize(sz,sz,true)end
self._image:pushdest()rtk.color.set(self.color)local a=0.65-0.5*(1-1/self.elevation)local inflection=radius
local origin=-math.log(1/(pad))for i=radius+pad,1,-1 do
if i>inflection then
gfx.a2=-math.log((i-inflection)/(pad))/origin*a
else
end
gfx.circle(pad+radius,pad+radius,i,1,1)end
gfx.a2=1
gfx.set(0,0,0,1)self._image:popdest()self._needs_draw=false
end
self._image:draw(x-pad,y-pad,alpha)end
function rtk.Shadow:_draw_rectangle(x,y,alpha)local tt,tr,tb,tl=self.tt,self.tr,self.tb,self.tl
local pad=math.max(tl,tr,tt,tb)if self:_needs_generate()then
local w=self.w+(tl+tr)+pad*2
local h=self.h+(tt+tb)+pad*2
if not self._image then
self._image=rtk.Image(w,h)else
self._image:resize(w,h,true)end
self._image:pushdest()rtk.color.set(self.color)local a=gfx.a
gfx.a=1
for i=0,pad do
gfx.a2=a*(i+1)/pad
rtk.gfx.roundrect(pad+i,pad+i,self.w+tl+tr-i*2,self.h+tt+tb-i*2,self.elevation,0)end
self._image:popdest()self._needs_draw=false
end
if tr>0 then
self._image:blit{sx=pad+tl+self.w,sw=tr+pad,sh=nil,dx=x+self.w,dy=y-tt-pad,alpha=alpha
}end
if tb>0 then
self._image:blit{sy=pad+tt+self.h,sw=self.w+tl+pad,sh=tb+pad,dx=x-tl-pad,dy=y+self.h,alpha=alpha
}end
if tt>0 then
self._image:blit{sx=0,sy=0,sw=self.w+tl+pad,sh=pad+tt,dx=x-tl-pad,dy=y-tt-pad,alpha=alpha
}end
if tl>0 then
self._image:blit{sx=0,sy=pad+tt,sw=pad+tl,sh=self.h,dx=x-tl-pad,dy=y,alpha=alpha
}end
end
end)()

__mod_rtk_nativemenu=(function()
local rtk=__mod_rtk_core
rtk.NativeMenu=rtk.class('rtk.NativeMenu')rtk.NativeMenu.static.SEPARATOR=0
function rtk.NativeMenu:initialize(menu)self._menustr=nil
if menu then
self:set(menu)end
end
function rtk.NativeMenu:set(menu)self.menu=menu
if menu then
self:_parse()end
end
function rtk.NativeMenu:_parse(submenu)self._item_by_idx={}self._item_by_id={}self._order=self:_parse_submenu(self.menu)end
function rtk.NativeMenu:_parse_submenu(submenu,baseitem)local order=baseitem or {}for n,menuitem in ipairs(submenu)do
if type(menuitem) ~='table' then
menuitem={label=menuitem}else
menuitem=table.shallow_copy(menuitem)if not menuitem.label then
menuitem.label=table.remove(menuitem,1)end
end
if menuitem.submenu then
menuitem=self:_parse_submenu(menuitem.submenu,menuitem)menuitem.submenu=nil
elseif menuitem.label~=rtk.NativeMenu.SEPARATOR then
local idx=#self._item_by_idx+1
menuitem.index=idx
self._item_by_idx[idx]=menuitem
end
if menuitem.id then
self._item_by_id[tostring(menuitem.id)]=menuitem
end
order[#order+1]=menuitem
end
return order
end
local function _get_item_attr(item,attr)local val=item[attr]
if type(val)=='function' then
return val()else
return val
end
end
function rtk.NativeMenu:_build_menustr(submenu,items)items=items or {}local menustr=''for n,item in ipairs(submenu)do
if not _get_item_attr(item, 'hidden') then
local flags=''if _get_item_attr(item, 'disabled') then
flags=flags .. '#'end
if _get_item_attr(item, 'checked') then
flags=flags .. '!'end
if item.label==rtk.NativeMenu.SEPARATOR then
menustr=menustr .. '|'elseif #item>0 then
menustr=menustr .. flags .. '>' .. item.label .. '|' .. self:_build_menustr(item, items) .. '<|'else
items[#items+1]=item
menustr=menustr .. flags .. item.label .. '|'end
end
end
return menustr,items
end
function rtk.NativeMenu:item(idx_or_id)if not idx_or_id or not self._item_by_idx then
return nil
end
local item=self._item_by_id[tostring(idx_or_id)] or self._item_by_id[idx_or_id]
if item then
return item
end
return self._item_by_idx[idx_or_id]
end
function rtk.NativeMenu:items()if not self._item_by_idx then
return function()end
end
local i=0
local n=#self._item_by_idx
return function()i=i+1
if i<=n then
return self._item_by_idx[i]
end
end
end
function rtk.NativeMenu:open(x,y)rtk.window:request_mouse_cursor(rtk.mouse.cursors.POINTER)assert(self.menu, 'menu must be set before open()')if not self._order then
self:_parse()end
local menustr,items=self:_build_menustr(self._order)local future=rtk.Future()rtk.defer(function()gfx.x=x
gfx.y=y
local choice=gfx.showmenu(menustr)local item
if choice>0 then
item=items[tonumber(choice)]
end
rtk._drag_candidates=nil
rtk.window:queue_mouse_refresh()future:resolve(item)end)return future
end
function rtk.NativeMenu:open_at_mouse()return self:open(gfx.mouse_x,gfx.mouse_y)end
function rtk.NativeMenu:open_at_widget(widget,halign,valign)assert(widget.drawn, "rtk.NativeMenu.open_at_widget() called before widget was drawn")local x=widget.clientx
local y=widget.clienty
if halign=='right' then
x=x+widget.calc.w
end
if valign ~='top' then
y=y+widget.calc.h
end
return self:open(x,y)end
end)()

__mod_rtk_widget=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Widget=rtk.class('rtk.Widget')rtk.Widget.static.LEFT=0
rtk.Widget.static.TOP=0
rtk.Widget.static.CENTER=1
rtk.Widget.static.RIGHT=2
rtk.Widget.static.BOTTOM=2
rtk.Widget.static.POSITION_INFLOW=0x01
rtk.Widget.static.POSITION_FIXED=0x02
rtk.Widget.static.RELATIVE=rtk.Widget.POSITION_INFLOW|0x10
rtk.Widget.static.ABSOLUTE=0x20
rtk.Widget.static.FIXED=rtk.Widget.POSITION_FIXED|0x40
rtk.Widget.static.FIXED_FLOW=rtk.Widget.POSITION_INFLOW|rtk.Widget.POSITION_FIXED|0x80
rtk.Widget.static.BOX=1
rtk.Widget.static.FULL=rtk.Widget.BOX|2
rtk.Widget.static.REFLOW_DEFAULT=nil
rtk.Widget.static.REFLOW_NONE=0
rtk.Widget.static.REFLOW_PARTIAL=1
rtk.Widget.static.REFLOW_FULL=2
rtk.Widget.static._calc_border=function(self,value)if type(value)=='string' then
local parts=string.split(value)if #parts==1 then
return {{rtk.color.rgba(parts[1])},1}elseif #parts==2 then
local width=parts[1]:gsub('px', '')return {{rtk.color.rgba(parts[2])},tonumber(width)}else
error('invalid border format')end
elseif value then
assert(type(value)=='table', 'border must be string or table')if #value==1 then
return {rtk.color.rgba({value[1]}),1}elseif #value==2 then
return value
elseif #value==4 then
return {value,1}else
log.exception('invalid border value: %s', table.tostring(value))error('invalid border value')end
end
end
rtk.Widget.static._calc_padding_or_margin=function(value)if not value then
return 0,0,0,0
elseif type(value)=='number' then
return value,value,value,value
else
if type(value)=='string' then
local parts=string.split(value)value={}for i=1,#parts do
local sz=parts[i]:gsub('px', '')value[#value+1]=tonumber(sz)end
end
if #value==1 then
return value[1],value[1],value[1],value[1]
elseif #value==2 then
return value[1],value[2],value[1],value[2]
elseif #value==3 then
return value[1],value[2],value[3],value[2]
elseif #value==4 then
return value[1],value[2],value[3],value[4]
else
error('invalid value')end
end
end
rtk.Widget.register{x=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL,reflow_uses_exterior_value=true,},y=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL,reflow_uses_exterior_value=true,},w=rtk.Attribute{type='number',reflow=rtk.Widget.REFLOW_FULL,reflow_uses_exterior_value=true,animate=function(self,anim,scale)local calculated=anim.resolve(anim.easingfunc(anim.pct))local exterior
if anim.doneval and anim.doneval~=rtk.Attribute.NIL and anim.doneval~=rtk.Attribute.DEFAULT then
exterior=(anim.pct<1 and calculated or anim.doneval)/(scale or rtk.scale.value)end
if anim.dst==0 or anim.dst>1 then
exterior = (type(exterior) == 'number' and exterior > 0 and exterior <= 1.0) and 1.01 or exterior
end
return calculated,exterior
end,},h=rtk.Attribute{type='number',reflow=rtk.Widget.REFLOW_FULL,reflow_uses_exterior_value=true,animate=rtk.Reference('w'),},z=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL},minw = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},minh = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},maxw = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},maxh = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},halign=rtk.Attribute{default=rtk.Widget.LEFT,calculate={left=rtk.Widget.LEFT,center=rtk.Widget.CENTER,right=rtk.Widget.RIGHT},},valign=rtk.Attribute{default=rtk.Widget.TOP,calculate={top=rtk.Widget.TOP,center=rtk.Widget.CENTER,bottom=rtk.Widget.BOTTOM},},scalability=rtk.Attribute{default=rtk.Widget.FULL,reflow=rtk.Widget.REFLOW_FULL,calculate={box=rtk.Widget.BOX,full=rtk.Widget.FULL},},position=rtk.Attribute{default=rtk.Widget.RELATIVE,reflow=rtk.Widget.REFLOW_FULL,calculate={relative=rtk.Widget.RELATIVE,absolute=rtk.Widget.ABSOLUTE,fixed=rtk.Widget.FIXED,['fixed-flow']=rtk.Widget.FIXED_FLOW
},},box=nil,offx=nil,offy=nil,clientx=nil,clienty=nil,padding=rtk.Attribute{replaces={'tpadding', 'rpadding', 'bpadding', 'lpadding'},get=function(self,attr,target)return {target.tpadding,target.rpadding,target.bpadding,target.lpadding}end,reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)local t,r,b,l=rtk.Widget.static._calc_padding_or_margin(value)target.tpadding,target.rpadding,target.bpadding,target.lpadding=t,r,b,l
return {t,r,b,l}end
},tpadding=rtk.Attribute{priority=true,reflow=rtk.Widget.REFLOW_FULL},rpadding=rtk.Reference('tpadding'),bpadding=rtk.Reference('tpadding'),lpadding=rtk.Reference('tpadding'),margin=rtk.Attribute{default=0,replaces={'tmargin', 'rmargin', 'bmargin', 'lmargin'},get=function(self,attr,target)return {target.tmargin,target.rmargin,target.bmargin,target.lmargin}end,reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)local t,r,b,l=rtk.Widget.static._calc_padding_or_margin(value)target.tmargin,target.rmargin,target.bmargin,target.lmargin=t,r,b,l
return {t,r,b,l}end
},tmargin=rtk.Attribute{priority=true,reflow=rtk.Widget.REFLOW_FULL},rmargin=rtk.Reference('tmargin'),bmargin=rtk.Reference('tmargin'),lmargin=rtk.Reference('tmargin'),border=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)local border=rtk.Widget.static._calc_border(self,value)target.tborder=border
target.rborder=border
target.bborder=border
target.lborder=border
target.border_uniform=true
return border
end
},tborder=rtk.Attribute{priority=true,reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)target.border_uniform=false
return rtk.Widget.static._calc_border(self,value)end,},rborder=rtk.Reference('tborder'),bborder=rtk.Reference('tborder'),lborder=rtk.Reference('tborder'),visible=rtk.Attribute{default=true,reflow=rtk.Widget.REFLOW_FULL},disabled=false,ghost=rtk.Attribute{default=false,reflow=rtk.Widget.REFLOW_NONE,},tooltip=nil,cursor=nil,alpha=rtk.Attribute{default=1.0,reflow=rtk.Widget.REFLOW_NONE,},autofocus=nil,bg=rtk.Attribute{reflow=rtk.Widget.REFLOW_NONE,calculate=function(self,attr,value,target,animation)if not value and animation then
local parent=self.parent
value=parent and parent.calc.bg or rtk.theme.bg
end
return value and {rtk.color.rgba(value)}end,},hotzone=rtk.Attribute{reflow=rtk.Widget.REFLOW_NONE,replaces={'thotzone', 'rhotzone', 'bhotzone', 'lhotzone'},get=function(self,attr,target)return {target.thotzone,target.rhotzone,target.bhotzone,target.lhotzone}end,calculate=function(self,attr,value,target)local t,r,b,l=rtk.Widget.static._calc_padding_or_margin(value)target.thotzone,target.rhotzone,target.bhotzone,target.lhotzone=t,r,b,l
target._hotzone_set=true
return {t,r,b,l}end
},thotzone=rtk.Attribute{priority=true,reflow=rtk.Widget.REFLOW_NONE,calculate=function(self,attr,value,target)target._hotzone_set=true
return value
end,},rhotzone=rtk.Reference('thotzone'),bhotzone=rtk.Reference('thotzone'),lhotzone=rtk.Reference('thotzone'),scroll_on_drag=true,show_scrollbar_on_drag=true,touch_activate_delay=nil,realized=false,drawn=false,viewport=nil,window=nil,mouseover=false,hovering=false,debug=nil,id=nil,ref=nil,refs=nil,}local _refs_metatable={__mode='v',__index=function(table,key)return table.__self:_ref(table,key)end,__newindex=function(table,key,value)rawset(table,key,value)table.__empty=false
end
}local _calc_metatable={__call=function(table,_,attr,instant)return table.__self:_calc(attr,instant)end
}rtk.Widget.static.last_index=0
function rtk.Widget:__allocate()self.__id=tostring(rtk.Widget.static.last_index)rtk.Widget.static.last_index=rtk.Widget.static.last_index+1
end
function rtk.Widget:initialize(attrs,...)self.refs=setmetatable({__empty=true,__self=self},_refs_metatable)self.calc=setmetatable({__self=self,border_uniform=true},_calc_metatable)local clsattrs=self.class.attributes
local tables={clsattrs.defaults,...}local merged={}for n=1,#tables do
for k,v in pairs(tables[n])do
merged[k]=v
end
end
if attrs then
for k,v in pairs(attrs)do
local meta=clsattrs[k] or rtk.Attribute.NIL
local attr=meta.alias
if attr then
merged[attr]=v
end
local replaces=meta.replaces
if replaces then
for n=1,#replaces do
merged[replaces[n]]=nil
end
end
if not tonumber(k)then
merged[k]=v
end
end
if attrs.ref then
rtk._refs[attrs.ref]=self
self.refs[attrs.ref]=self
end
end
self.id=self.__id
self:_setattrs(merged)self._last_mousedown_time=0
self._last_reflow_scale=nil
end
function rtk.Widget:__tostring()local clsname=self.class.name:gsub('rtk.', '')if not self.calc then
return string.format('<%s (uninitialized)>', clsname)end
local info=self:__tostring_info()info=info and string.format('<%s>', info) or ''return string.format('%s%s[%s] (%s,%s %sx%s)',clsname,info,self.id,self.calc.x,self.calc.y,self.calc.w,self.calc.h
)end
function rtk.Widget:__tostring_info()end
function rtk.Widget:_setattrs(attrs)if not attrs then
return
end
local clsattrs=self.class.attributes
local priority={}local calc=self.calc
for k,v in pairs(attrs)do
local meta=clsattrs[k]
if meta and not meta.priority then
if v==rtk.Attribute.FUNCTION then
v=clsattrs[k].default_func(self,k)elseif v==rtk.Attribute.NIL then
v=nil
end
local calculated=self:_calc_attr(k,v,nil,meta)self:_set_calc_attr(k,v,calculated,calc,meta)else
priority[#priority+1]=k
end
self[k]=v
end
if #priority==0 then
return
end
for _,k in ipairs(priority)do
local v=self[k]
if v==rtk.Attribute.FUNCTION then
v=clsattrs[k].default_func(self,k)self[k]=v
end
if v~=nil then
if v==rtk.Attribute.NIL then
v=nil
self[k]=nil
end
local calculated=self:_calc_attr(k,v)self:_set_calc_attr(k,v,calculated,calc)end
end
end
function rtk.Widget:_ref(table,key)if self.parent then
return self.parent.refs[key]
else
return rtk._refs[key]
end
end
function rtk.Widget:_get_debug_color()if not self.debug_color then
local x=self.id:hash()*100
x=x ~(x<<13)x=x ~(x>>7)x=x ~(x<<17)local color=table.pack(rtk.color.rgba(x%16777216))local luma=rtk.color.luma(color)if luma<0.2 then
color=table.pack(rtk.color.mod(color,1,1,2.5))elseif luma>0.8 then
color=table.pack(rtk.color.mod(color,1,1,0.75))end
self.debug_color=color
end
return self.debug_color
end
function rtk.Widget:_draw_debug_box(offx,offy,event)local calc=self.calc
if not self.debug and not rtk.debug or not calc.w then
return false
end
if not self.debug and event.debug~=self then
return false
end
local color=self:_get_debug_color()gfx.set(color[1],color[2],color[3],0.2)local x=calc.x+offx
local y=calc.y+offy
gfx.rect(x,y,calc.w,calc.h,1)gfx.set(color[1],color[2],color[3],0.4)gfx.rect(x,y,calc.w,calc.h,0)local tp,rp,bp,lp=self:_get_padding_and_border()if tp>0 or rp>0 or bp>0 or lp>0 then
gfx.set(color[1],color[2],color[3],0.8)gfx.rect(x+lp,y+tp,calc.w-lp-rp,calc.h-tp-bp,0)end
return true
end
function rtk.Widget:_draw_debug_info(event)local calc=self.calc
local parts={{ 15, "#6e2e2e", tostring(self.class.name:gsub("rtk.", "")) },{ 15, "#378b48", string.format('#%s', self.id) },{ 17, "#cccccc", " | " },{ 15, "#555555", string.format("%.1f", calc.x) },{ 15,  "#777777", " , " },{ 15, "#555555", string.format("%.1f", calc.y) },{ 17, "#cccccc", " | " },{ 15, "#555555", string.format("%.1f", calc.w) },{ 13,  "#777777", "  x  " },{ 15, "#555555", string.format("%.1f", calc.h) },}local sizes={}local bw,bh=0,0
for n,part in ipairs(parts)do
local sz,_,str=table.unpack(part)gfx.setfont(1,rtk.theme.default_font,sz)local w,h=gfx.measurestr(str)sizes[n]={w,h}bw=bw+w
bh=math.max(bh,h)end
bw=bw+20
bh=bh+10
local x=self.clientx
local y=self.clienty
if x+bw>self.window.calc.w then
x=self.window.calc.w-bw
elseif x<0 then
x=0
end
if y-bh>=0 then
y=math.max(0,y-bh)else
y=math.min(y+calc.h,self.window.calc.h-bh)end
rtk.color.set('#ffffff')gfx.rect(x,y,bw,bh,1)rtk.color.set('#777777')gfx.rect(x,y,bw,bh,0)gfx.x=x+10
for n,part in ipairs(parts)do
local sz,color,str=table.unpack(part)rtk.color.set(color)gfx.y=y+(bh-sizes[n][2])/2
gfx.setfont(1,rtk.theme.default_font,sz)gfx.drawstr(str)end
end
function rtk.Widget:attr(attr,value,trigger,reflow)return self:_attr(attr,value,trigger,reflow,nil,false)end
function rtk.Widget:sync(attr,value,calculated,trigger,reflow)return self:_attr(attr,value,trigger,reflow,calculated,true)end
function rtk.Widget:_attr(attr,value,trigger,reflow,calculated,sync)local meta=self.class.attributes.get(attr)if value==rtk.Attribute.DEFAULT then
if meta.default==rtk.Attribute.FUNCTION then
value=meta.default_func(self,attr)else
value=meta.default
end
elseif value==rtk.Attribute.NIL then
value=nil
end
local oldval=self[attr]
local oldcalc=self.calc[attr]
local replaces=meta.replaces
if replaces then
for i=1,#replaces do
self[replaces[i]]=nil
end
end
if calculated==nil then
calculated=self:_calc_attr(attr,value,nil,meta)end
if not rawequal(value,oldval)or calculated~=oldcalc or replaces or trigger then
self[attr]=value
self:_set_calc_attr(attr,value,calculated,self.calc,meta)self:_handle_attr(attr,calculated,oldcalc,trigger==nil or trigger,reflow,sync)end
return self
end
function rtk.Widget:_calc_attr(attr,value,target,meta,namespace,widget)target=target or self.calc
meta=meta or self.class.attributes.get(attr)if meta.type then
value=meta.type(value)end
local calculate=meta.calculate
if calculate then
local tp=type(calculate)if tp=='table' then
if value==nil then
value=calculate[rtk.Attribute.NIL]
else
value=calculate[value] or value
end
elseif tp=='function' then
if value==rtk.Attribute.NIL then
value=nil
end
value=calculate(self,attr,value,target)end
end
return value
end
function rtk.Widget:_set_calc_attr(attr,value,calculated,target,meta)meta=meta or self.class.attributes.get(attr)if meta.set then
meta.set(self,attr,value,calculated,target)else
self.calc[attr]=calculated
end
end
function rtk.Widget:_calc(attr,instant)if not instant then
local anim=self:get_animation(attr)if anim and anim.dst then
return anim.dst
end
end
local meta=self.class.attributes.get(attr)if meta.get then
return meta.get(self,attr,self.calc)else
return self.calc[attr]
end
end
function rtk.Widget:move(x,y)self:attr('x', x)self:attr('y', y)return self
end
function rtk.Widget:resize(w,h)self:attr('w', w)self:attr('h', h)return self
end
function rtk.Widget:_get_relative_pos_to_viewport()local x,y=0,0
local widget=self
while widget do
x=x+widget.calc.x
y=y+widget.calc.y
if widget.viewport and widget.viewport==widget.parent then
break
end
widget=widget.parent
end
return x,y
end
function rtk.Widget:scrolltoview(margin,allowh,allowv,smooth)if not self.visible or not self.box or not self.viewport then
return self
end
local calc=self.calc
local vcalc=self.viewport.calc
local tmargin,rmargin,bmargin,lmargin=rtk.Widget.static._calc_padding_or_margin(margin or 0)local left,top=nil,nil
local absx,absy=self:_get_relative_pos_to_viewport()if allowh~=false then
if absx-lmargin<self.viewport.scroll_left then
left=absx-lmargin
elseif absx+calc.w+rmargin>self.viewport.scroll_left+vcalc.w then
left=absx+calc.w+rmargin-vcalc.w
end
end
if allowv~=false then
if absy-tmargin<self.viewport.scroll_top then
top=absy-tmargin
elseif absy+calc.h+bmargin>self.viewport.scroll_top+vcalc.h then
top=absy+calc.h+bmargin-vcalc.h
end
end
self.viewport:scrollto(left,top,smooth)return self
end
function rtk.Widget:hide()if self.calc.visible~=false then
return self:attr('visible', false)end
return self
end
function rtk.Widget:show()if self.calc.visible~=true then
return self:attr('visible', true)end
return self
end
function rtk.Widget:toggle()if self.calc.visible==true then
return self:hide()else
return self:show()end
end
function rtk.Widget:focused(event)return rtk.focused==self
end
function rtk.Widget:focus(event)if rtk.focused and rtk.focused~=self then
rtk.focused:blur(event,self)end
if rtk.focused==nil and self:_handle_focus(event)~=false then
rtk.focused=self
if self.parent then
self.parent:_set_focused_child(self)end
self:queue_draw()return true
end
return false
end
function rtk.Widget:blur(event,other)if not self:focused(event)then
return true
end
if self:_handle_blur(event,other)~=false then
rtk.focused=nil
if self.parent then
self.parent:_set_focused_child(nil)end
self:queue_draw()return true
end
return false
end
function rtk.Widget:animate(kwargs)assert(kwargs and (kwargs.attr or #kwargs > 0), 'missing animation arguments')local calc=self.calc
local attr=kwargs.attr or kwargs[1]
local meta=self.class.attributes.get(attr)local key=string.format('%s.%s', self.id, attr)local curanim=rtk._animations[key]
local curdst=curanim and curanim.dst or self.calc[attr]
if curdst == kwargs.dst and not meta.calculate and attr ~= 'w' and attr ~= 'h' then
if curanim then
return curanim.future
elseif not kwargs.src then
return rtk.Future():resolve(self)end
end
kwargs.attr=attr
kwargs.key=key
kwargs.widget=self
kwargs.attrmeta=meta
kwargs.stepfunc=(meta.animate and meta.animate~=rtk.Attribute.NIL)and meta.animate
kwargs.calculate=meta.calculate
kwargs.sync_exterior_value=meta.reflow_uses_exterior_value
if kwargs.dst==rtk.Attribute.DEFAULT then
if meta.default==rtk.Attribute.FUNCTION then
kwargs.dst=meta.default_func(self,attr)else
kwargs.dst=meta.default
end
end
local calcsrc,calcdst
local doneval=kwargs.dst or rtk.Attribute.DEFAULT
if attr == 'w' or attr == 'h' then
if(not kwargs.src or kwargs.src==rtk.Attribute.NIL)or(kwargs.src<=1.0 and kwargs.src>=0)then
if kwargs.src==rtk.Attribute.NIL then
kwargs.src=nil
end
kwargs.src=(calc[attr] or 0)*(kwargs.src or 1)calcsrc=true
end
if(not kwargs.dst or kwargs.dst==rtk.Attribute.NIL)or(kwargs.dst<=1.0 and kwargs.dst>0)then
if kwargs.dst==rtk.Attribute.NIL then
kwargs.dst=nil
end
local current=self[attr]
local current_calc=calc[attr]
self[attr]=kwargs.dst
calc[attr]=meta.calculate and meta.calculate(self,attr,kwargs.dst,{},true)or kwargs.dst
local window=self:_slow_get_window()if not window then
return rtk.Future():resolve(self)end
window:reflow(rtk.Widget.REFLOW_FULL)kwargs.dst=calc[attr] or 0
calcdst=true
self[attr]=current
calc[attr]=current_calc
window:reflow(rtk.Widget.REFLOW_FULL)end
end
if not calcdst and meta.calculate then
kwargs.dst=meta.calculate(self,attr,kwargs.dst,{},true)doneval=kwargs.dst or rtk.Attribute.DEFAULT
end
if curdst==kwargs.dst then
if curanim then
return curanim.future
elseif not kwargs.src then
return rtk.Future():resolve(self)end
end
if kwargs.doneval==nil then
kwargs.doneval=doneval
end
if not kwargs.src then
kwargs.src=self:calc(attr,true)calc[attr]=kwargs.src
calcsrc=kwargs.src~=nil
end
if not calcsrc and meta.calculate then
kwargs.src=meta.calculate(self,attr,kwargs.src,{},true)calc[attr]=kwargs.src
end
return rtk.queue_animation(kwargs)end
function rtk.Widget:cancel_animation(attr)local anim=self:get_animation(attr)if anim then
anim.future:cancel()end
return anim
end
function rtk.Widget:get_animation(attr)local key=self.id .. '.' .. attr
return rtk._animations[key]
end
function rtk.Widget:setcolor(color,amul)rtk.color.set(color,(amul or 1)*self.calc.alpha)return self
end
function rtk.Widget:queue_draw()if self.window then
self.window:queue_draw()end
return self
end
function rtk.Widget:queue_reflow(mode,widget)local window=self:_slow_get_window()if window then
window:queue_reflow(mode,widget or self)end
return self
end
function rtk.Widget:reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
local expw,exph
if not boxx then
if self.box then
expw,exph=self:_reflow(table.unpack(self.box))else
return
end
else
self.viewport=viewport
self.window=window
self.box={boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh}expw,exph=self:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)end
self.realized=true
self:onreflow()return calc.x,calc.y,calc.w,calc.h,expw or fillw,exph or fillh
end
function rtk.Widget:_get_padding()local calc=self.calc
local scale=rtk.scale.value
return
(calc.tpadding or 0)*scale,(calc.rpadding or 0)*scale,(calc.bpadding or 0)*scale,(calc.lpadding or 0)*scale
end
function rtk.Widget:_get_border_sizes()local calc=self.calc
return
calc.tborder and calc.tborder[2] or 0,calc.rborder and calc.rborder[2] or 0,calc.bborder and calc.bborder[2] or 0,calc.lborder and calc.lborder[2] or 0
end
function rtk.Widget:_get_padding_and_border()local tp,rp,bp,lp=self:_get_padding()local tb,rb,bb,lb=self:_get_border_sizes()return tp+tb,rp+rb,bp+bb,lp+lb
end
function rtk.Widget:_adjscale(val,scale,box)if not val then
return
elseif val>0 and val<=1.0 and box then
return val*box
elseif(self.calc.scalability&rtk.Widget.FULL~=rtk.Widget.FULL)then
return val
else
return val*(scale or rtk.scale.value)end
end
function rtk.Widget:_get_box_pos(boxx,boxy)local x=self.x or 0
local y=self.y or 0
if self.calc.scalability&rtk.Widget.FULL==rtk.Widget.FULL then
local scale=rtk.scale.value
return scale*x+boxx,scale*y+boxy
else
return x+boxx,y+boxy
end
end
local function _get_content_dimension(size,box,padding,fill,clamp,greedy,scale)if size then
if box and size<-1 then
return box+(size*scale)-padding
elseif box and size<=1.0 then
return greedy and math.abs(box*size)-padding
else
return(size*scale)-padding
end
end
if fill and box and greedy then
return box-padding
end
end
function rtk.Widget:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,scale,greedyw,greedyh)scale=self:_adjscale(scale or 1)local tp,rp,bp,lp=self:_get_padding_and_border()local w=_get_content_dimension(self.w,boxw,lp+rp,fillw,clampw,greedyw,scale)local h=_get_content_dimension(self.h,boxh,tp+bp,fillh,clamph,greedyh,scale)local minw,maxw,minh,maxh=self:_get_min_max_sizes(boxw,boxh,greedyw,greedyh,scale)maxw=maxw and clampw and math.min(maxw,boxw)or maxw
maxh=maxh and clamph and math.min(maxh,boxh)or maxh
minw=minw and minw-lp-rp
maxw=maxw and maxw-lp-rp
minh=minh and minh-tp-bp
maxh=maxh and maxh-tp-bp
return w,h,tp,rp,bp,lp,minw,maxw,minh,maxh
end
function rtk.Widget:_get_min_max_sizes(boxw,boxh,greedyw,greedyh,scale)local minw,maxw,minh,maxh=self.minw,self.maxw,self.minh,self.maxh
return minw and((minw>1 or minw<=0)and(minw*scale)or(greedyw and minw*boxw)),maxw and((maxw>1 or maxw<=0)and(maxw*scale)or(greedyw and maxw*boxw)),minh and((minh>1 or minh<=0)and(minh*scale)or(greedyh and minh*boxh)),maxh and((maxh>1 or maxh<=0)and(maxh*scale)or(greedyh and maxh*boxh))end
function rtk.Widget:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)calc.w=rtk.clamp(w or(fillw and greedyw and(boxw-lp-rp)or 0),minw,maxw)+lp+rp
calc.h=rtk.clamp(h or(fillh and greedyh and(boxh-tp-bp)or 0),minh,maxh)+tp+bp
return fillw and greedyw,fillh and greedyh
end
function rtk.Widget:_realize_geometry()self.realized=true
end
function rtk.Widget:_slow_get_window()if self.window then
return self.window
end
local w=self.parent
while w do
if w.window then
return w.window
end
w=w.parent
end
end
function rtk.Widget:_is_mouse_over(clparentx,clparenty,event)local calc=self.calc
local x,y=calc.x+clparentx,calc.y+clparenty
local w,h=calc.w,calc.h
if calc._hotzone_set then
local scale=rtk.scale.value
local l=(calc.lhotzone or 0)*scale
local t=(calc.thotzone or 0)*scale
x=x-l
y=y-t
w=w+l+(calc.rhotzone or 0)*scale
h=h+t+(calc.bhotzone or 0)*scale
end
return self.window and self.window.in_window and
rtk.point_in_box(event.x,event.y,x,y,w,h)end
function rtk.Widget:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)self.offx=offx
self.offy=offy
self.clientx=cltargetx+offx+self.calc.x
self.clienty=cltargety+offy+self.calc.y
self.drawn=true
end
function rtk.Widget:_draw_bg(offx,offy,alpha,event)local calc=self.calc
if calc.bg and not calc.ghost then
self:setcolor(calc.bg,alpha)gfx.rect(calc.x+offx,calc.y+offy,calc.w,calc.h,1)end
end
function rtk.Widget:_draw_tooltip(clientx,clienty,clientw,clienth,tooltip)tooltip=tooltip or self.calc.tooltip
local font=rtk.Font(table.unpack(rtk.theme.tooltip_font))local segments,w,h=font:layout(tooltip,clientw-10,clienth-10,true)rtk.color.set(rtk.theme.tooltip_bg)local x=rtk.clamp(clientx,0,clientw-w-10)local y=rtk.clamp(clienty+16,0,clienth-h-10-self.calc.h)gfx.rect(x,y,w+10,h+10,1)rtk.color.set(rtk.theme.tooltip_text)gfx.rect(x,y,w+10,h+10,0)font:draw(segments,x+5,y+5,w,h)end
function rtk.Widget:_unpack_border(border,alpha)local color,thickness=table.unpack(border)if color then
self:setcolor(color or rtk.theme.button,alpha*self.calc.alpha)end
return thickness or 1
end
function rtk.Widget:_draw_borders(offx,offy,alpha,all)if self.ghost then
return
end
local calc=self.calc
if not all and calc.border_uniform and not calc.tborder then
return
end
local x,y,w,h=calc.x+offx,calc.y+offy,calc.w,calc.h
local tb,rb,bb,lb
all=all or(calc.border_uniform and calc.tborder)if all then
local thickness=self:_unpack_border(all,alpha)if thickness==1 then
gfx.rect(x,y,w,h,0)return
elseif thickness==0 then
return
else
tb,rb,bb,lb=all,all,all,all
end
else
tb,rb,bb,lb=calc.tborder,calc.rborder,calc.bborder,calc.lborder
end
if tb then
local thickness=self:_unpack_border(tb,alpha)gfx.rect(x,y,w,thickness,1)end
if rb and w>0 then
local thickness=self:_unpack_border(rb,alpha)gfx.rect(x+w-thickness,y,thickness,h,1)end
if bb and h>0 then
local thickness=self:_unpack_border(bb,alpha)gfx.rect(x,y+h-thickness,w,thickness,1)end
if lb then
local thickness=self:_unpack_border(lb,alpha)gfx.rect(x,y,thickness,h,1)end
end
function rtk.Widget:_get_touch_activate_delay(event)if not rtk.touchscroll then
return self.touch_activate_delay or 0
else
if not self.viewport or not self.viewport:scrollable()then
return 0
end
return(not self:focused(event)and event.button==rtk.mouse.BUTTON_LEFT)and
self.touch_activate_delay or rtk.touch_activate_delay
end
end
function rtk.Widget:_should_handle_event(listen)if not listen and rtk._modal and rtk._modal[self.id]~=nil then
return true
else
return listen
end
end
function rtk.Widget:_handle_event(clparentx,clparenty,event,clipped,listen)local calc=self.calc
if not listen and rtk._modal and rtk._modal[self.id]==nil then
return false
end
local dnd=rtk.dnd
if not clipped and self:_is_mouse_over(clparentx,clparenty,event)then
event:set_widget_mouseover(self,clparentx,clparenty)if event.type==rtk.Event.MOUSEMOVE and not calc.disabled then
if dnd.dragging==self then
if calc.cursor then
self.window:request_mouse_cursor(calc.cursor)end
self:_handle_dragmousemove(event,dnd.arg)elseif self.hovering==false then
if event.buttons==0 or self:focused(event)then
if not event.handled and not self.mouseover and self:_handle_mouseenter(event)then
self.hovering=true
self:_handle_mousemove(event)self:queue_draw()elseif event.handled and self.mouseover then
self.mouseover=false
elseif rtk.debug then
self:queue_draw()end
else
if dnd.arg and not event.simulated and rtk.dnd.droppable then
if dnd.dropping==self or self:_handle_dropfocus(event,dnd.dragging,dnd.arg)then
if dnd.dropping then
if dnd.dropping~=self then
dnd.dropping:_handle_dropblur(event,dnd.dragging,dnd.arg)elseif not event.simulated then
dnd.dropping:_handle_dropmousemove(event,dnd.dragging,dnd.arg)end
end
event:set_handled(self)self:queue_draw()dnd.dropping=self
end
end
end
if not self.mouseover and(not event.handled or event.handled==self)and event.buttons==0 then
self.mouseover=true
self:queue_draw()end
else
if event.handled then
self:_handle_mouseleave(event)self.hovering=false
self.mouseover=false
self:queue_draw()else
self.mouseover=true
self:_handle_mousemove(event)event:set_handled(self)end
end
elseif event.type==rtk.Event.MOUSEDOWN and not calc.disabled then
local duration=event:get_button_duration()if duration==0 then
event:set_widget_pressed(self)end
if not event.handled then
local state=event:get_button_state(self)or 0
local threshold=self:_get_touch_activate_delay(event)if duration>=threshold and state==0 and event:is_widget_pressed(self)then
event:set_button_state(self,1)if self:_handle_mousedown(event)~=false then
self:_accept_mousedown(event,duration,state)end
elseif state&8==0 then
if duration>=rtk.long_press_delay then
if self:_handle_longpress(event)then
self:queue_draw()event:set_button_state(self,state|8|16)else
event:set_button_state(self,state|8)end
end
end
if self:focused(event)then
event:set_handled(self)end
end
elseif event.type==rtk.Event.MOUSEUP and not calc.disabled then
if not event.handled then
if not dnd.dragging then
self:_deferred_mousedown(event)end
if self:_handle_mouseup(event)then
event:set_handled(self)self:queue_draw()end
local state=event:get_button_state(self)or 0
if state&2~=0 then
if state&16==0 and not dnd.dragging then
if self:_handle_click(event)then
event:set_handled(self)self:queue_draw()end
local last=rtk.mouse.last[event.button]
if state&4~=0 then
if self:_handle_doubleclick(event)then
event:set_handled(self)self:queue_draw()end
self._last_mousedown_time=0
end
end
end
end
if dnd.dropping==self then
self:_handle_dropblur(event,dnd.dragging,dnd.arg)if self:_handle_drop(event,dnd.dragging,dnd.arg)then
event:set_handled(self)self:queue_draw()end
end
self:queue_draw()elseif event.type==rtk.Event.MOUSEWHEEL and not calc.disabled then
if not event.handled and self:_handle_mousewheel(event)then
event:set_handled(self)self:queue_draw()end
elseif event.type==rtk.Event.DROPFILE and not calc.disabled then
if not event.handled and self:_handle_dropfile(event)then
event:set_handled(self)self:queue_draw()end
end
elseif event.type==rtk.Event.MOUSEMOVE then
self.mouseover=false
if dnd.dragging==self then
self.window:request_mouse_cursor(calc.cursor)self:_handle_dragmousemove(event,dnd.arg)end
if self.hovering==true then
if dnd.dragging~=self then
self:_handle_mouseleave(event)self:queue_draw()self.hovering=false
end
elseif event.buttons~=0 and dnd.dropping then
if dnd.dropping==self then
self:_handle_dropblur(event,dnd.dragging,dnd.arg)dnd.dropping=nil
end
self:queue_draw()end
else
self.mouseover=false
end
if rtk.touchscroll and event.type==rtk.Event.MOUSEUP and self:focused(event)then
if event:get_button_state('mousedown-handled') == self then
event:set_handled(self)self:queue_draw()end
end
if event.type==rtk.Event.KEY and not event.handled then
if self:focused(event)and self:_handle_keypress(event)then
event:set_handled(self)self:queue_draw()end
end
if event.type==rtk.Event.WINDOWCLOSE then
self:_handle_windowclose(event)end
if(self.mouseover or dnd.dragging==self)and calc.cursor then
self.window:request_mouse_cursor(calc.cursor)end
return true
end
function rtk.Widget:_deferred_mousedown(event,x,y)local mousedown_handled=event:get_button_state('mousedown-handled')if not mousedown_handled and event:is_widget_pressed(self)and not event:get_button_state(self)then
local downevent=event:clone{type=rtk.Event.MOUSEDOWN,simulated=true,x=x or event.x,y=y or event.y}if self:_handle_mousedown(downevent)then
self:_accept_mousedown(event)end
end
end
function rtk.Widget:_accept_mousedown(event,duration,state)event:set_button_state('mousedown-handled', self)event:set_handled(self)if not event.simulated and event.time-self._last_mousedown_time<=rtk.double_click_delay then
event:set_button_state(self,(state or 0)|2|4)self._last_mousedown_time=0
else
event:set_button_state(self,(state or 0)|2)self._last_mousedown_time=event.time
end
self:queue_draw()end
function rtk.Widget:_unrealize()self.realized=false
end
function rtk.Widget:_release_modal(event)end
function rtk.Widget:onattr(attr,value,oldval,trigger,sync)return true end
function rtk.Widget:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ok=self:onattr(attr,value,oldval,trigger,sync)if ok~=false then
local redraw
if reflow==rtk.Widget.REFLOW_DEFAULT then
local meta=self.class.attributes.get(attr)reflow=meta.reflow or rtk.Widget.REFLOW_PARTIAL
redraw=meta.redraw
end
if reflow~=rtk.Widget.REFLOW_NONE then
self:queue_reflow(reflow)elseif redraw~=false then
self:queue_draw()end
if attr=='visible' then
if not value then
self:_unrealize()end
self.realized=false
self.drawn=false
elseif attr=='ref' then
assert(not oldval, 'ref cannot be changed')self.refs[self.ref]=self
rtk._refs[self.ref]=self
if self.parent then
self.parent:_sync_child_refs(self, 'add')end
end
end
return ok
end
function rtk.Widget:ondrawpre(offx,offy,alpha,event)end
function rtk.Widget:_handle_drawpre(offx,offy,alpha,event)return self:ondrawpre(offx,offy,alpha,event)end
function rtk.Widget:ondraw(offx,offy,alpha,event)end
function rtk.Widget:_handle_draw(offx,offy,alpha,event)return self:ondraw(offx,offy,alpha,event)end
function rtk.Widget:onmousedown(event)end
function rtk.Widget:_handle_mousedown(event)local ok=self:onmousedown(event)if ok~=false then
local autofocus=self.calc.autofocus
if autofocus or
(autofocus==nil and self.onclick~=rtk.Widget.onclick)then
self:focus(event)return ok or self:focused(event)else
return ok or false
end
end
return ok
end
function rtk.Widget:onmouseup(event)end
function rtk.Widget:_handle_mouseup(event)return self:onmouseup(event)end
function rtk.Widget:onmousewheel(event)end
function rtk.Widget:_handle_mousewheel(event)return self:onmousewheel(event)end
function rtk.Widget:onclick(event)end
function rtk.Widget:_handle_click(event)return self:onclick(event)end
function rtk.Widget:ondoubleclick(event)end
function rtk.Widget:_handle_doubleclick(event)return self:ondoubleclick(event)end
function rtk.Widget:onlongpress(event)end
function rtk.Widget:_handle_longpress(event)return self:onlongpress(event)end
function rtk.Widget:onmouseenter(event)end
function rtk.Widget:_handle_mouseenter(event)local ok=self:onmouseenter(event)if ok~=false then
return self.calc.autofocus or ok
end
return ok
end
function rtk.Widget:onmouseleave(event)end
function rtk.Widget:_handle_mouseleave(event)return self:onmouseleave(event)end
function rtk.Widget:onmousemove(event)end
rtk.Widget.onmousemove=nil
function rtk.Widget:_handle_mousemove(event)if self.onmousemove then
return self:onmousemove(event)end
end
function rtk.Widget:onkeypress(event)end
function rtk.Widget:_handle_keypress(event)return self:onkeypress(event)end
function rtk.Widget:onfocus(event)return true
end
function rtk.Widget:_handle_focus(event)return self:onfocus(event)end
function rtk.Widget:onblur(event,other)return true
end
function rtk.Widget:_handle_blur(event,other)return self:onblur(event,other)end
function rtk.Widget:ondragstart(event,x,y,t)end
function rtk.Widget:_handle_dragstart(event,x,y,t)local draggable,droppable=self:ondragstart(event,x,y,t)if draggable==nil then
return false,false
end
return draggable,droppable
end
function rtk.Widget:ondragend(event,dragarg)end
function rtk.Widget:_handle_dragend(event,dragarg)self._last_mousedown_time=0
return self:ondragend(event,dragarg)end
function rtk.Widget:ondragmousemove(event,dragarg)end
function rtk.Widget:_handle_dragmousemove(event,dragarg)return self:ondragmousemove(event,dragarg)end
function rtk.Widget:ondropfocus(event,source,dragarg)return false
end
function rtk.Widget:_handle_dropfocus(event,source,dragarg)return self:ondropfocus(event,source,dragarg)end
function rtk.Widget:ondropmousemove(event,source,dragarg)end
function rtk.Widget:_handle_dropmousemove(event,source,dragarg)return self:ondropmousemove(event,source,dragarg)end
function rtk.Widget:ondropblur(event,source,dragarg)end
function rtk.Widget:_handle_dropblur(event,source,dragarg)return self:ondropblur(event,source,dragarg)end
function rtk.Widget:ondrop(event,source,dragarg)return false
end
function rtk.Widget:_handle_drop(event,source,dragarg)return self:ondrop(event,source,dragarg)end
function rtk.Widget:onreflow()end
function rtk.Widget:_handle_reflow()return self:onreflow()end
function rtk.Widget:ondropfile(event)end
function rtk.Widget:_handle_dropfile(event)return self:ondropfile(event)end
function rtk.Widget:_handle_windowclose(event)end
end)()

__mod_rtk_viewport=(function()
local rtk=__mod_rtk_core
rtk.Viewport=rtk.class('rtk.Viewport', rtk.Widget)rtk.Viewport.static.SCROLLBAR_NEVER=0
rtk.Viewport.static.SCROLLBAR_HOVER=1
rtk.Viewport.static.SCROLLBAR_AUTO=2
rtk.Viewport.static.SCROLLBAR_ALWAYS=3
rtk.Viewport.register{[1]=rtk.Attribute{alias='child'},child=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},scroll_left=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_NONE,calculate=function(self,attr,value,target)return math.round(value)end,},scroll_top=rtk.Reference('scroll_left'),smoothscroll=rtk.Attribute{reflow=rtk.Widget.REFLOW_NONE},scrollbar_size=15,vscrollbar=rtk.Attribute{default=rtk.Viewport.SCROLLBAR_HOVER,calculate={never=rtk.Viewport.SCROLLBAR_NEVER,always=rtk.Viewport.SCROLLBAR_ALWAYS,hover=rtk.Viewport.SCROLLBAR_HOVER,auto=rtk.Viewport.SCROLLBAR_AUTO,},},vscrollbar_offset=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_NONE,},vscrollbar_gutter=25,hscrollbar=rtk.Attribute{default=rtk.Viewport.SCROLLBAR_NEVER,calculate=rtk.Reference('vscrollbar'),},hscrollbar_offset=0,hscrollbar_gutter=25,flexw=false,flexh=true,shadow=nil,elevation=20,show_scrollbar_on_drag=false,touch_activate_delay=0,}function rtk.Viewport:initialize(attrs,...)rtk.Widget.initialize(self,attrs,self.class.attributes.defaults,...)self:_handle_attr('child', self.calc.child, nil, true)self:_handle_attr('bg', self.calc.bg)self._backingstore=nil
self._needs_clamping=false
self._last_draw_scroll_left=nil
self._last_draw_scroll_top=nil
self._vscrollx=0
self._vscrolly=0
self._vscrollh=0
self._vscrolla={current=self.calc.vscrollbar==rtk.Viewport.SCROLLBAR_ALWAYS and 0.1 or 0,target=0,}self._vscroll_in_gutter=false
end
function rtk.Viewport:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ok=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if attr=='child' then
if oldval then
oldval:_unrealize()oldval.viewport=nil
oldval.parent=nil
oldval.window=nil
self:_sync_child_refs(oldval, 'remove')if rtk.focused==oldval then
self:_set_focused_child(nil)end
end
if value then
value.viewport=self
value.parent=self
value.window=self.window
self:_sync_child_refs(value, 'add')if rtk.focused==value then
self:_set_focused_child(value)end
end
elseif attr=='bg' then
value=value or rtk.theme.bg
local luma=rtk.color.luma(value)local offset=math.max(0,1-(1.5-3*luma)^2)self._scrollbar_alpha_proximity=0.16*(1+offset^0.2)self._scrollbar_alpha_hover=0.40*(1+offset^0.4)self._scrollbar_color=luma < 0.5 and '#ffffff' or '#000000'elseif attr=='shadow' then
self._shadow=nil
elseif attr == 'scroll_top' or attr == 'scroll_left' then
self._needs_clamping=true
end
return true
end
function rtk.Viewport:_sync_child_refs(child,action)return rtk.Container._sync_child_refs(self,child,action)end
function rtk.Viewport:_set_focused_child(child)return rtk.Container._set_focused_child(self,child)end
function rtk.Viewport:focused(event)return rtk.Container.focused(self,event)end
function rtk.Viewport:remove()self:attr('child', nil)end
function rtk.Viewport:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)local hpadding=lp+rp
local vpadding=tp+bp
local inner_maxw=rtk.clamp(w or(boxw-hpadding),minw,maxw)local inner_maxh=rtk.clamp(h or(boxh-vpadding),minh,maxh)local scrollw,scrollh=0,0
if calc.vscrollbar==rtk.Viewport.SCROLLBAR_ALWAYS or
(calc.vscrollbar==rtk.Viewport.SCROLLBAR_AUTO and self._vscrollh>0)then
scrollw=calc.scrollbar_size*rtk.scale.value
inner_maxw=inner_maxw-scrollw
end
if calc.hscrollbar==rtk.Viewport.SCROLLBAR_ALWAYS or
(calc.hscrollbar==rtk.Viewport.SCROLLBAR_AUTO and self._hscrollh>0)then
scrollh=calc.scrollbar_size*rtk.scale.value
inner_maxh=inner_maxh-scrollh
end
local child=calc.child
local innerw,innerh
local hmargin,vmargin
local ccalc
if child and child.visible==true then
ccalc=child.calc
hmargin=ccalc.lmargin+ccalc.rmargin
vmargin=ccalc.tmargin+ccalc.bmargin
inner_maxw=inner_maxw-hmargin
inner_maxh=inner_maxh-vmargin
local wx,wy,ww,wh=self:_reflow_child(inner_maxw,inner_maxh,uiscale,window,greedyw,greedyh)local pass2=false
if calc.vscrollbar==rtk.Viewport.SCROLLBAR_AUTO then
if scrollw==0 and wh>inner_maxh then
scrollw=calc.scrollbar_size*rtk.scale.value
inner_maxw=inner_maxw-scrollw
pass2=ww>inner_maxw
elseif scrollw>0 and wh<=inner_maxh then
pass2=ww>=inner_maxw
inner_maxw=inner_maxw+scrollw
scrollw=0
end
end
if pass2 then
wx,wy,ww,wh=self:_reflow_child(inner_maxw,inner_maxh,uiscale,window,greedyw,greedyh)end
if greedyw then
if calc.halign==rtk.Widget.CENTER then
wx=wx+math.max(0,inner_maxw-ccalc.w)/2
elseif calc.halign==rtk.Widget.RIGHT then
wx=wx+math.max(0,(inner_maxw-ccalc.w)-rp)end
end
if greedyh then
if calc.valign==rtk.Widget.CENTER then
wy=wy+math.max(0,inner_maxh-ccalc.h)/2
elseif calc.valign==rtk.Widget.BOTTOM then
wy=wy+math.max(0,(inner_maxh-ccalc.h)-bp)end
end
ccalc.x=wx
ccalc.y=wy
child:_realize_geometry()innerw=math.ceil(rtk.clamp(ww+wx,fillw and greedyw and inner_maxw,inner_maxw))innerh=math.ceil(rtk.clamp(wh+wy,fillh and greedyh and inner_maxh,inner_maxh))else
innerw,innerh=inner_maxw,inner_maxh
hmargin,vmargin=0,0
end
calc.w=rtk.clamp((w or(innerw+scrollw+hmargin))+hpadding,minw,maxw)calc.h=rtk.clamp((h or(innerh+scrollh+vmargin))+vpadding,minh,maxh)if not self._backingstore then
self._backingstore=rtk.Image(innerw,innerh)else
self._backingstore:resize(innerw,innerh,false)end
self._vscrollh=0
self._needs_clamping=true
if ccalc then
self._scroll_clamp_left=math.max(0,ccalc.w-calc.w+lp+rp+ccalc.lmargin+ccalc.rmargin)self._scroll_clamp_top=math.max(0,ccalc.h-calc.h+tp+bp+ccalc.tmargin+ccalc.bmargin)end
end
function rtk.Viewport:_reflow_child(maxw,maxh,uiscale,window,greedyw,greedyh)local calc=self.calc
return calc.child:reflow(0,0,maxw,maxh,false,false,not calc.flexw,not calc.flexh,uiscale,self,window,greedyw,greedyh
)end
function rtk.Viewport:_realize_geometry()local calc=self.calc
local tp,rp,bp,lp=self:_get_padding_and_border()if self.child then
local innerh=self._backingstore.h
local ch=self.child.calc.h
if ch>innerh then
self._vscrollx=calc.x+calc.w-calc.scrollbar_size*rtk.scale.value-calc.vscrollbar_offset
self._vscrolly=calc.y+calc.h*calc.scroll_top/ch+tp
self._vscrollh=calc.h*innerh/ch
end
end
if self.shadow then
if not self._shadow then
self._shadow=rtk.Shadow(calc.shadow)end
self._shadow:set_rectangle(calc.w,calc.h,calc.elevation)end
self._pre={tp=tp,rp=rp,bp=bp,lp=lp}end
function rtk.Viewport:_unrealize()self._backingstore=nil
if self.child then
self.child:_unrealize()end
end
function rtk.Viewport:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
local pre=self._pre
self.cltargetx=cltargetx
self.cltargety=cltargety
local x=calc.x+offx+pre.lp
local y=calc.y+offy+pre.tp
local lastleft,lasttop
local scrolled=calc.scroll_left~=self._last_draw_scroll_left or
calc.scroll_top~=self._last_draw_scroll_top
if scrolled then
lastleft,lasttop=self._last_draw_scroll_left or 0,self._last_draw_scroll_top or 0
if self:onscrollpre(lastleft,lasttop,event)==false then
calc.scroll_left=lastleft or 0
calc.scroll_top=lasttop
scrolled=false
else
self._last_draw_scroll_left=calc.scroll_left
self._last_draw_scroll_top=calc.scroll_top
end
end
if y+calc.h<0 or y>cliph or calc.ghost then
return false
end
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,1.0,event)local child=calc.child
if child and child.realized then
self:_clamp()x=x+child.calc.lmargin
y=y+child.calc.tmargin
self._backingstore:blit{src=gfx.dest,sx=x,sy=y,mode=rtk.Image.FAST_BLIT}self._backingstore:pushdest()child:_draw(-calc.scroll_left,-calc.scroll_top,1.0,event,calc.w,calc.h,cltargetx+x,cltargety+y,0,0
)child:_draw_debug_box(-calc.scroll_left,-calc.scroll_top,event)self._backingstore:popdest()self._backingstore:blit{dx=x,dy=y,alpha=alpha*calc.alpha}self:_draw_scrollbars(offx,offy,cltargetx,cltargety,alpha,event)end
if calc.shadow then
self._shadow:draw(calc.x+offx,calc.y+offy,alpha*calc.alpha)end
self:_draw_borders(offx,offy,alpha)if scrolled then
self:onscroll(lastleft,lasttop,event)end
self:_handle_draw(offx,offy,alpha,event)end
function rtk.Viewport:_draw_scrollbars(offx,offy,cltargetx,cltargety,alpha,event)if self._vscrolla.current==0 or self._vscrollh==0 then
return
end
local calc=self.calc
local scrx=offx+self._vscrollx
local scry=offy+calc.y+calc.h*calc.scroll_top/self.child.calc.h
self:setcolor(self._scrollbar_color,self._vscrolla.current*alpha)gfx.rect(scrx,scry,calc.scrollbar_size*rtk.scale.value,self._vscrollh+1,1)end
function rtk.Viewport:_calc_scrollbar_alpha(clparentx,clparenty,event,dragchild)local calc=self.calc
if calc.vscrollbar==rtk.Viewport.SCROLLBAR_NEVER then
return
end
local dragself=(rtk.dnd.dragging==self)local alpha=0
local duration=0.2
if self._vscrollh>0 then
if not rtk._modal or rtk.is_modal(self)then
local overthumb=event:get_button_state(self.id)if self.mouseover then
if overthumb==nil and self._vscroll_in_gutter then
overthumb=rtk.point_in_box(event.x,event.y,clparentx+self._vscrollx,clparenty+calc.y+calc.h*calc.scroll_top/self.child.calc.h,calc.scrollbar_size*rtk.scale.value,self._vscrollh
)end
if event.type==rtk.Event.MOUSEDOWN then
event:set_button_state(self.id,overthumb)end
end
if self._vscroll_in_gutter or dragself then
if overthumb then
alpha=self._scrollbar_alpha_hover
duration=0.1
else
alpha=self._scrollbar_alpha_proximity
end
elseif self.mouseover or calc.vscrollbar==rtk.Viewport.SCROLLBAR_ALWAYS then
alpha=self._scrollbar_alpha_proximity
elseif dragchild and dragchild.show_scrollbar_on_drag then
alpha=self._scrollbar_alpha_proximity
duration=0.15
end
elseif calc.vscrollbar==rtk.Viewport.SCROLLBAR_ALWAYS then
alpha=self._scrollbar_alpha_proximity
end
end
if alpha~=self._vscrolla.target then
if alpha==0 then
duration=0.3
end
rtk.queue_animation{key=string.format('%s.vscrollbar', self.id),src=self._vscrolla.current,dst=alpha,duration=duration,update=function(value)self._vscrolla.current=value
self:queue_draw()end,}self._vscrolla.target=alpha
self:queue_draw()end
end
function rtk.Viewport:_handle_event(clparentx,clparenty,event,clipped,listen)local calc=self.calc
local pre=self._pre
listen=self:_should_handle_event(listen)local x=calc.x+clparentx
local y=calc.y+clparenty
local hovering=rtk.point_in_box(event.x,event.y,x,y,calc.w,calc.h)and self.window.in_window
local dragging=rtk.dnd.dragging
local is_child_dragging=dragging and dragging.viewport==self
local child=self.child
if event.type==rtk.Event.MOUSEMOVE then
self._vscroll_in_gutter=false
if listen and is_child_dragging and dragging.scroll_on_drag then
if event.y-20<y then
self:scrollby(0,-math.max(5,math.abs(y-event.y)),false)elseif event.y+20>y+calc.h then
self:scrollby(0,math.max(5,math.abs(y+calc.h-event.y)),false)end
elseif listen and not dragging and not event.handled and hovering then
if calc.vscrollbar~=rtk.Viewport.SCROLLBAR_NEVER and self._vscrollh>0 then
local gutterx=self._vscrollx+clparentx-calc.vscrollbar_gutter
local guttery=calc.y+clparenty
if rtk.point_in_box(event.x,event.y,gutterx,guttery,calc.vscrollbar_gutter+calc.scrollbar_size*rtk.scale.value,calc.h)then
self._vscroll_in_gutter=true
if event.x>=self._vscrollx+clparentx then
event:set_handled(self)end
end
end
end
elseif listen and not event.handled and event.type==rtk.Event.MOUSEDOWN then
if not self:cancel_animation('scroll_top') then
self:_reset_touch_scroll()end
if self._vscroll_in_gutter and event.x>=self._vscrollx+clparentx then
local scrolly=self:_get_vscrollbar_client_pos()if event.y<scrolly or event.y>scrolly+self._vscrollh then
self:_handle_scrollbar(event,nil,self._vscrollh/2,true)end
event:set_handled(self)end
end
if(not event.handled or event.type==rtk.Event.MOUSEMOVE)and
not(event.type==rtk.Event.MOUSEMOVE and self.window:_is_touch_scrolling(self))and
child and child.visible and child.realized then
self:_clamp()child:_handle_event(x-calc.scroll_left+pre.lp+child.calc.lmargin,y-calc.scroll_top+pre.tp+child.calc.tmargin,event,clipped or not hovering,listen
)end
if listen and hovering and not event.handled and event.type==rtk.Event.MOUSEWHEEL then
if child and self._vscrollh>0 and event.wheel~=0 then
local distance=event.wheel*math.min(calc.h/2,120)self:scrollby(0,distance)event:set_handled(self)end
end
listen=rtk.Widget._handle_event(self,clparentx,clparenty,event,clipped,listen)self.mouseover=self.mouseover or(child and child.mouseover)self:_calc_scrollbar_alpha(clparentx,clparenty,event,is_child_dragging and dragging)return listen
end
function rtk.Viewport:_get_vscrollbar_client_pos()local calc=self.calc
return self.clienty+calc.h*calc.scroll_top/self.child.calc.h
end
function rtk.Viewport:_handle_scrollbar(event,hoffset,voffset,gutteronly,natural)local calc=self.calc
local pre=self._pre
if voffset~=nil then
self:cancel_animation('scroll_top')if gutteronly then
local ssy=self:_get_vscrollbar_client_pos()if event.y>=ssy and event.y<=ssy+self._vscrollh then
return false
end
end
local target
if natural then
target=calc.scroll_top+(voffset-event.y)else
local pct=rtk.clamp(event.y-self.clienty-voffset,0,calc.h)/calc.h
target=pct*(self.child.calc.h)end
self:scrollto(calc.scroll_left,target,false)end
end
function rtk.Viewport:_handle_dragstart(event,x,y,t)local draggable,droppable=self:ondragstart(self,event,x,y,t)if draggable~=nil then
return draggable,droppable
end
if math.abs(y-event.y)>0 then
if self._vscroll_in_gutter and event.x>=self._vscrollx+self.offx+self.cltargetx then
return {true,y-self:_get_vscrollbar_client_pos(),nil,false},false
elseif rtk.touchscroll and event.buttons&rtk.mouse.BUTTON_LEFT~=0 and self._vscrollh>0 then
self.window:_set_touch_scrolling(self,true)return {true,y,{{x,y,t}},true},false
end
end
return false,false
end
function rtk.Viewport:_handle_dragmousemove(event,arg)local ok=rtk.Widget._handle_dragmousemove(self,event)if ok==false or event.simulated then
return ok
end
local vscrollbar,lasty,samples,natural=table.unpack(arg)if vscrollbar then
self:_handle_scrollbar(event,nil,lasty,false,natural)if natural then
arg[2]=event.y
samples[#samples+1]={event.x,event.y,event.time}end
self.window:request_mouse_cursor(rtk.mouse.cursors.POINTER,true)end
return true
end
function rtk.Viewport:_reset_touch_scroll()if self.window then
self.window:_set_touch_scrolling(self,false)end
end
function rtk.Viewport:_handle_dragend(event,arg)local ok=rtk.Widget._handle_dragend(self,event)if ok==false then
return ok
end
local vscrollbar,lasty,samples,natural=table.unpack(arg)if natural then
local now=event.time
local x1,y1,t1=event.x,event.y,event.time
for i=#samples,1,-1 do
local x,y,t=table.unpack(samples[i])if now-t>0.2 then
break
end
x1,y1,t1=x,y,t
end
local v=0
if t1~=event.time then
v=(event.y-y1)-(event.time-t1)end
local distance=v*rtk.scale.value
local x,y=self:_get_clamped_scroll(self.calc.scroll_left,self.calc.scroll_top-distance)local duration=1
self:animate{attr='scroll_top', dst=y, duration=duration, easing='out-cubic'}:done(function()self:_reset_touch_scroll()end):cancelled(function()self:_reset_touch_scroll()end)end
self:queue_draw()event:set_handled(self)return true
end
function rtk.Viewport:_scrollto(x,y,smooth,animx,animy)local calc=self.calc
if not smooth or not self.realized then
x=x or self.scroll_left
y=y or self.scroll_top
if x==calc.scroll_left and y==calc.scroll_top then
return
end
self._needs_clamping=true
calc.scroll_left=x
calc.scroll_top=y
self.scroll_left=calc.scroll_left
self.scroll_top=calc.scroll_top
self:queue_draw()else
x,y=self:_get_clamped_scroll(x or calc.scroll_left,y or calc.scroll_top)animx=animx or self:get_animation('scroll_left')animy=animy or self:get_animation('scroll_top')if calc.scroll_left~=x and(not animx or animx.dst~=x)then
self:animate{attr='scroll_left', dst=x, duration=0.15}end
if calc.scroll_top~=y and(not animy or animy.dst~=y)then
self:animate{attr='scroll_top', dst=y, duration=0.2, easing='out-sine'}end
end
end
function rtk.Viewport:_get_smoothscroll(override)if override~=nil then
return override
end
local calc=self.calc
if calc.smoothscroll~=nil then
return calc.smoothscroll
end
return rtk.smoothscroll
end
function rtk.Viewport:scrollto(x,y,smooth)self:_scrollto(x,y,self:_get_smoothscroll(smooth))end
function rtk.Viewport:scrollby(offx,offy,smooth)local calc=self.calc
local x,y,animx,animy
smooth=self:_get_smoothscroll(smooth)if smooth then
animx=self:get_animation('scroll_left')animy=self:get_animation('scroll_top')x=(animx and animx.dst or calc.scroll_left)+(offx or 0)y=(animy and animy.dst or calc.scroll_top)+(offy or 0)else
x=calc.scroll_left+(offx or 0)y=calc.scroll_top+(offy or 0)end
self:_scrollto(x,y,smooth,animx,animy)end
function rtk.Viewport:scrollable()if not self.child then
return false
end
local vcalc=self.calc
local ccalc=self.child.calc
return ccalc.w>vcalc.w or ccalc.h>vcalc.h
end
function rtk.Viewport:_get_clamped_scroll(left,top)return rtk.clamp(left,0,self._scroll_clamp_left),rtk.clamp(top,0,self._scroll_clamp_top)end
function rtk.Viewport:_clamp()if self._needs_clamping then
local calc=self.calc
calc.scroll_left,calc.scroll_top=self:_get_clamped_scroll(self.scroll_left,self.scroll_top)self.scroll_left,self.scroll_top=calc.scroll_left,calc.scroll_top
self._needs_clamping=false
end
end
function rtk.Viewport:onscrollpre(last_left,last_top,event)end
function rtk.Viewport:onscroll(last_left,last_top,event)end
end)()

__mod_rtk_popup=(function()
local rtk=__mod_rtk_core
rtk.Popup=rtk.class('rtk.Popup', rtk.Viewport)rtk.Popup.AUTOCLOSE_DISABLED=0
rtk.Popup.AUTOCLOSE_LOCAL=1
rtk.Popup.AUTOCLOSE_GLOBAL=2
rtk.Popup.register{anchor=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},margin=rtk.Attribute{default=20,reflow=rtk.Widget.REFLOW_FULL,},width_from_anchor=rtk.Attribute{default=true,reflow=rtk.Widget.REFLOW_FULL,},overlay=rtk.Attribute{default=function(self,attr)return rtk.theme.popup_overlay
end,calculate=rtk.Reference('bg'),},autoclose=rtk.Attribute{default=rtk.Popup.AUTOCLOSE_LOCAL,calculate={['disabled']=rtk.Popup.AUTOCLOSE_DISABLED,['local']=rtk.Popup.AUTOCLOSE_LOCAL,['global']=rtk.Popup.AUTOCLOSE_GLOBAL,[true]=rtk.Popup.AUTOCLOSE_LOCAL,[false]=rtk.Popup.AUTOCLOSE_DISABLED,}},opened=false,bg=rtk.Attribute{default=function(self,attr)return rtk.theme.popup_bg or {rtk.color.mod(rtk.theme.bg,1,1,rtk.theme.popup_bg_brightness,0.96)}end,},border=rtk.Attribute{default=function(self,attr)return rtk.theme.popup_border
end,},shadow=rtk.Attribute{default=function()return rtk.theme.popup_shadow
end,},visible=false,elevation=35,padding=10,z=1000,}function rtk.Popup:initialize(attrs,...)rtk.Viewport.initialize(self,attrs,self.class.attributes.defaults,...)self._popup_visible=false
end
function rtk.Popup:_handle_event(clparentx,clparenty,event,clipped,listen)listen=rtk.Viewport._handle_event(self,clparentx,clparenty,event,clipped,listen)if event.type==rtk._touch_activate_event and self.mouseover then
event:set_handled(self)end
return listen
end
function rtk.Popup:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
local anchor=calc.anchor
if anchor then
local y=anchor.clienty
local wh=self.window.calc.h
if y<wh/2 then
y=y+anchor.calc.h
boxh=math.floor(math.min(boxh,wh-y-calc.bmargin))else
boxh=math.floor(math.min(boxh,y-calc.tmargin))end
if self.width_from_anchor then
self.w=math.floor(anchor.calc.w/uiscale)end
end
rtk.Viewport._reflow(self,boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)if anchor then
self._realize_on_draw=true
end
end
function rtk.Popup:_realize_geometry()local calc=self.calc
local anchor=calc.anchor
local st,sb=calc.elevation,calc.elevation
if anchor and anchor.clientx and(anchor.realized or self._popup_visible)then
calc.x=anchor.clientx
if anchor.clienty+anchor.calc.h+calc.h<self.window.calc.h then
calc.y=anchor.clienty+anchor.calc.h
if calc.width_from_anchor then
calc.tborder=nil
calc.bborder=calc.rborder
calc.border_uniform=false
end
st=5
else
calc.y=anchor.clienty-calc.h
if calc.width_from_anchor then
calc.tborder=calc.rborder
calc.bborder=nil
calc.border_uniform=false
end
sb=5
end
end
rtk.Viewport._realize_geometry(self)self._shadow:set_rectangle(calc.w,calc.h,nil,st,calc.elevation,sb,calc.elevation)end
function rtk.Popup:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)if self.overlay and not self.anchor then
self:setcolor(self.calc.overlay or self.calc.bg,alpha)gfx.rect(0,0,self.window.calc.w,self.window.calc.h,1)end
if self._realize_on_draw then
self:_realize_geometry()self._realize_on_draw=false
end
rtk.Viewport._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)end
function rtk.Popup:_release_modal(event)local ac=self.calc.autoclose
if ac==rtk.Popup.AUTOCLOSE_GLOBAL or(ac==rtk.Popup.AUTOCLOSE_LOCAL and not event.simulated)then
self:_close(event)end
end
function rtk.Popup:open(attrs)if self.calc.opened or self:onopen()==false then
return self
end
local calc=self.calc
local anchor=calc.anchor
if not attrs and not anchor then
attrs = {valign='center', halign='center'}end
if calc.visible and not self:get_animation('alpha') then
return self
end
rtk.reset_modal()if not self.parent then
local window=(anchor and anchor.window)or(attrs and attrs.window)or rtk.window
assert(window, 'no rtk.Window has been created or explicitly passed to open()')window:add(self,attrs)if anchor and not anchor.clientx then
rtk.defer(self._open,self,attrs)return self
end
end
self:_open(attrs)return self
end
function rtk.Popup:_open(attrs)local anchor=self.calc.anchor
if self:get_animation('alpha') then
self:cancel_animation('alpha')self:attr('alpha', 1)elseif anchor and not anchor.realized then
return false
end
self:sync('opened', true)self._popup_visible=true
rtk.add_modal(self,anchor)self:show()self:focus()self:scrollto(0,0)return true
end
function rtk.Popup:close()return self:_close()end
function rtk.Popup:_close(event)if not self.calc.visible or not self.calc.opened then
return
end
if self:onclose(event)==false then
return
end
self:sync('opened', false)self:animate{attr='alpha', dst=0, duration=0.15}:done(function()self:hide()self:attr('alpha', 1)self.window:remove(self)self._popup_visible=false
end)rtk.reset_modal()end
function rtk.Popup:_handle_windowclose(event)self:onclose(event)self:sync('opened', false)end
function rtk.Popup:onopen()end
function rtk.Popup:onclose(event)end
end)()

__mod_rtk_container=(function()
local rtk=__mod_rtk_core
rtk.Container=rtk.class('rtk.Container', rtk.Widget)rtk.Container.register{fillw=nil,fillh=nil,halign=nil,valign=nil,padding=nil,tpadding=nil,rpadding=nil,bpadding=nil,lpadding=nil,minw=nil,minh=nil,maxw=nil,maxh=nil,bg=nil,z=nil,children=nil,}function rtk.Container:initialize(attrs,...)self.children={}self._child_index_by_id=nil
self._reflowed_children={}self._z_indexes={}rtk.Widget.initialize(self,attrs,self.class.attributes.defaults,...)if attrs and #attrs>0 then
for i=1,#attrs do
local w=attrs[i]
self:add(w)end
end
end
function rtk.Container:_handle_mouseenter(event)local ret=self:onmouseenter(event)if ret~=false then
if self.bg or self.autofocus then
return true
end
end
return ret
end
function rtk.Container:_handle_mousemove(event)local ret=rtk.Widget._handle_mousemove(self,event)if ret~=false and self.hovering then
event:set_handled(self)return true
end
return ret
end
function rtk.Container:_draw_debug_box(offx,offy,event)if not rtk.Widget._draw_debug_box(self,offx,offy,event)then
return
end
gfx.set(1,1,1,1)for i=1,#self.children do
local widget,attrs=table.unpack(self.children[i])local cb=attrs._cellbox
if cb and widget.visible then
gfx.rect(offx+self.calc.x+cb[1],offy+self.calc.y+cb[2],cb[3],cb[4],0)end
end
end
function rtk.Container:_sync_child_refs(child,action)if child.refs and not child.refs.__empty then
if action=='add' then
local w=self
while w do
for k,v in pairs(child.refs)do
if k ~= '__self' and k ~= '__empty' then
w.refs[k]=v
end
end
w=w.parent
end
else
for k in pairs(child.refs)do
self.refs[k]=nil
end
end
end
end
function rtk.Container:_set_focused_child(child)local w=self
while w do
w._focused_child=child
w=w.parent
end
end
function rtk.Container:_validate_child(child)assert(rtk.isa(child, rtk.Widget), 'object being added to container is not subclassed from rtk.Widget')end
function rtk.Container:_reparent_child(child)self:_validate_child(child)if child.parent and child.parent~=self then
child.parent:remove(child)end
child.parent=self
child.window=self.window
self:_sync_child_refs(child, 'add')if rtk.focused==child then
self:_set_focused_child(child)end
end
function rtk.Container:_unparent_child(pos)local child=self.children[pos][1]
if child then
if child.visible then
child:_unrealize()end
child.parent=nil
child.window=nil
self:_sync_child_refs(child, 'remove')if rtk.focused==child then
self:_set_focused_child(nil)end
return child
end
end
function rtk.Container:focused(event)return rtk.focused==self or(event and event.type==rtk.Event.KEY and rtk.focused and rtk.focused==self._focused_child
)end
function rtk.Container:add(widget,attrs)self:_reparent_child(widget)self.children[#self.children+1]={widget,self:_calc_cell_attrs(widget,attrs)}self._child_index_by_id=nil
self:queue_reflow(rtk.Widget.REFLOW_FULL)return widget
end
function rtk.Container:update(widget,attrs,merge)local n=self:get_child_index(widget)assert(n, 'Widget not found in container')attrs=self:_calc_cell_attrs(widget,attrs)if merge then
local cellattrs=self.children[n][2]
table.merge(cellattrs,attrs)else
self.children[n][2]=attrs
end
self:queue_reflow(rtk.Widget.REFLOW_FULL)end
function rtk.Container:insert(pos,widget,attrs)self:_reparent_child(widget)table.insert(self.children,pos,{widget,self:_calc_cell_attrs(widget,attrs)})self._child_index_by_id=nil
self:queue_reflow(rtk.Widget.REFLOW_FULL)end
function rtk.Container:replace(index,widget,attrs)if index<=0 or index>#self.children then
return
end
local prev=self:_unparent_child(index)self:_reparent_child(widget)self.children[index]={widget,self:_calc_cell_attrs(widget,attrs)}self._child_index_by_id=nil
self:queue_reflow(rtk.Widget.REFLOW_FULL)return prev
end
function rtk.Container:remove_index(index)if index<=0 or index>#self.children then
return
end
local child=self:_unparent_child(index)table.remove(self.children,index)self._child_index_by_id=nil
self:queue_reflow(rtk.Widget.REFLOW_FULL)return child
end
function rtk.Container:remove(widget)local n=self:get_child_index(widget)if n~=nil then
self:remove_index(n)return n
end
end
function rtk.Container:remove_all()for i=1,#self.children do
local widget=self.children[i][1]
if widget and widget.visible then
widget:_unrealize()end
end
self.children={}self._child_index_by_id=nil
self:queue_reflow(rtk.Widget.REFLOW_FULL)end
function rtk.Container:_calc_cell_attrs(widget,attrs)attrs=attrs or widget.cell
if not attrs then
return {}end
local keys=table.keys(attrs)local calculated={}for n=1,#keys do
local k=keys[n]
calculated[k]=self:_calc_attr(k, attrs[k], calculated, nil, 'cell', widget)end
return calculated
end
function rtk.Container:_reorder(srcidx,targetidx)if srcidx~=nil and srcidx~=targetidx then
local widgetattrs=table.remove(self.children,srcidx)table.insert(self.children,rtk.clamp(targetidx,1,#self.children+1),widgetattrs)self._child_index_by_id=nil
self:queue_reflow(rtk.Widget.REFLOW_FULL)return true
else
return false
end
end
function rtk.Container:reorder(widget,targetidx)local srcidx=self:get_child_index(widget)return self:_reorder(srcidx,targetidx)end
function rtk.Container:reorder_before(widget,target)local srcidx=self:get_child_index(widget)local targetidx=self:get_child_index(target)if not srcidx or not targetidx then
return false
end
return self:_reorder(srcidx,targetidx>srcidx and targetidx-1 or targetidx)end
function rtk.Container:reorder_after(widget,target)local srcidx=self:get_child_index(widget)local targetidx=self:get_child_index(target)if not srcidx or not targetidx then
return false
end
return self:_reorder(srcidx,srcidx>targetidx and targetidx+1 or targetidx)end
function rtk.Container:get_child(idx)if idx<0 then
idx=#self.children+idx+1
end
local child=self.children[idx]
if child then
return child[1]
end
end
function rtk.Container:get_child_index(widget)if not self._child_index_by_id then
local cache={}for i=1,#self.children do
local widgetattrs=self.children[i]
if widgetattrs and widgetattrs[1].id then
cache[widgetattrs[1].id]=i
end
end
self._child_index_by_id=cache
end
return self._child_index_by_id[widget.id]
end
function rtk.Container:_handle_event(clparentx,clparenty,event,clipped,listen)local calc=self.calc
local x=calc.x+clparentx
local y=calc.y+clparenty
self.clientx,self.clienty=x,y
listen=self:_should_handle_event(listen)if y+calc.h<0 or y>self.window.calc.h or calc.ghost then
return false
end
local chmouseover
local zs=self._z_indexes
for zidx=#zs,1,-1 do
local zchildren=self._reflowed_children[zs[zidx]]
local nzchildren=zchildren and #zchildren or 0
for cidx=nzchildren,1,-1 do
local widget,attrs=table.unpack(zchildren[cidx])if widget and widget.realized and widget.parent then
local wx,wy
if widget.calc.position&rtk.Widget.POSITION_FIXED~=0 and self.viewport then
local vcalc=self.viewport.calc
wx,wy=x+vcalc.scroll_left,y+vcalc.scroll_top
else
wx,wy=x,y
end
self:_handle_event_child(clparentx,clparenty,event,clipped,listen,wx,wy,widget,attrs)chmouseover=chmouseover or widget.mouseover
end
end
end
listen=rtk.Widget._handle_event(self,clparentx,clparenty,event,clipped,listen)self.mouseover=self.mouseover or chmouseover
return listen
end
function rtk.Container:_handle_event_child(clparentx,clparenty,event,clipped,listen,wx,wy,child,attrs)return child:_handle_event(wx,wy,event,clipped,listen)end
function rtk.Container:_add_reflowed_child(widgetattrs,z)local z_children=self._reflowed_children[z]
if z_children then
z_children[#z_children+1]=widgetattrs
else
self._reflowed_children[z]={widgetattrs}end
end
function rtk.Container:_determine_zorders()local zs={}for z in pairs(self._reflowed_children)do
zs[#zs+1]=z
end
table.sort(zs)self._z_indexes=zs
end
function rtk.Container:_get_cell_padding(widget,attrs)local calc=widget.calc
local scale=rtk.scale.value
return
((attrs.tpadding or 0)+(calc.tmargin or 0))*scale,((attrs.rpadding or 0)+(calc.rmargin or 0))*scale,((attrs.bpadding or 0)+(calc.bmargin or 0))*scale,((attrs.lpadding or 0)+(calc.lmargin or 0))*scale
end
function rtk.Container:_set_cell_box(attrs,x,y,w,h)attrs._cellbox={math.round(x),math.round(y),math.round(w),math.round(h)}end
function rtk.Container:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
local x,y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw and greedyw,fillh and greedyh,clampw,clamph,nil,greedyw,greedyh
)local inner_maxw=rtk.clamp(w or(boxw-lp-rp),minw,maxw)local inner_maxh=rtk.clamp(h or(boxh-tp-bp),minh,maxh)local innerw=w or 0
local innerh=h or 0
clampw=clampw or w~=nil or fillw
clamph=clamph or h~=nil or fillh
self._reflowed_children={}self._child_index_by_id={}for n,widgetattrs in ipairs(self.children)do
local widget,attrs=table.unpack(widgetattrs)local wcalc=widget.calc
attrs._cellbox=nil
self._child_index_by_id[widget.id]=n
if widget.visible==true then
local ctp,crp,cbp,clp=self:_get_cell_padding(widget,attrs)attrs._minw=self:_adjscale(attrs.minw,uiscale,greedyw and inner_maxw)attrs._maxw=self:_adjscale(attrs.maxw,uiscale,greedyh and inner_maxw)attrs._minh=self:_adjscale(attrs.minh,uiscale,greedyh and inner_maxh)attrs._maxh=self:_adjscale(attrs.maxh,uiscale,greedyh and inner_maxh)local wx,wy,ww,wh=widget:reflow(0,0,rtk.clamp(inner_maxw-widget.x-clp-crp,attrs._minw,attrs._maxw),rtk.clamp(inner_maxh-widget.y-ctp-cbp,attrs._minh,attrs._maxh),attrs.fillw,attrs.fillh,clampw or attrs.maxw~=nil,clamph or attrs.maxh~=nil,uiscale,viewport,window,greedyw,greedyh
)ww=math.max(ww,attrs._minw or 0)wh=math.max(wh,attrs._minh or 0)attrs._halign=attrs.halign or calc.halign
attrs._valign=attrs.valign or calc.valign
if not attrs._halign or attrs._halign==rtk.Widget.LEFT or not greedyw then
wx=lp+clp
elseif attrs._halign==rtk.Widget.CENTER then
wx=lp+clp+math.max(0,(math.min(innerw,inner_maxw)-ww-clp-crp)/2)else
wx=lp+math.max(0,math.min(innerw,inner_maxw)-ww-crp)end
if not attrs._valign or attrs._valign==rtk.Widget.TOP or not greedyh then
wy=tp+ctp
elseif attrs._valign==rtk.Widget.CENTER then
wy=tp+ctp+math.max(0,(math.min(innerh,inner_maxh)-wh-ctp-cbp)/2)else
wy=tp+math.max(0,math.min(innerh,inner_maxh)-wh-cbp)end
wcalc.x=wcalc.x+wx
widget.box[1]=wx
wcalc.y=wcalc.y+wy
widget.box[2]=wy
self:_set_cell_box(attrs,wcalc.x,wcalc.y,ww+clp+crp,wh+ctp+cbp)widget:_realize_geometry()innerw=math.max(innerw,wcalc.x+ww-lp+crp)innerh=math.max(innerh,wcalc.y+wh-tp+cbp)self:_add_reflowed_child(widgetattrs,attrs.z or wcalc.z or 0)else
widget.realized=false
end
end
self:_determine_zorders()calc.x=x
calc.y=y
calc.w=math.ceil(rtk.clamp((w or innerw)+lp+rp,minw,maxw))calc.h=math.ceil(rtk.clamp((h or innerh)+tp+bp,minh,maxh))end
function rtk.Container:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local x,y=calc.x+offx,calc.y+offy
if y+calc.h<0 or y>cliph or calc.ghost then
return false
end
local wpx=parentx+calc.x
local wpy=parenty+calc.y
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,alpha,event)local child_alpha=alpha*self.alpha
for _,z in ipairs(self._z_indexes)do
for _,widgetattrs in ipairs(self._reflowed_children[z])do
local widget,attrs=table.unpack(widgetattrs)if attrs.bg and attrs._cellbox then
local cb=attrs._cellbox
self:setcolor(attrs.bg,child_alpha)gfx.rect(x+cb[1],y+cb[2],cb[3],cb[4],1)end
if widget and widget.realized then
local wx,wy=x,y
if widget.calc.position&rtk.Widget.POSITION_FIXED~=0 then
wx,wy=wpx,wpy
end
widget:_draw(wx,wy,child_alpha,event,clipw,cliph,cltargetx,cltargety,wpx,wpy)widget:_draw_debug_box(wx,wy,event)end
end
end
self:_draw_borders(offx,offy,alpha)self:_handle_draw(offx,offy,alpha,event)end
function rtk.Container:_unrealize()rtk.Widget._unrealize(self)for i=1,#self.children do
local widget=self.children[i][1]
if widget and widget.realized then
widget:_unrealize()end
end
end
end)()

__mod_rtk_window=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Window=rtk.class('rtk.Window', rtk.Container)rtk.Window.static.DOCK_BOTTOM=(function()return {0} end)()rtk.Window.static.DOCK_LEFT=(function()return {1} end)()rtk.Window.static.DOCK_TOP=(function()return {2} end)()rtk.Window.static.DOCK_RIGHT=(function()return {3} end)()rtk.Window.static.DOCK_FLOATING=(function()return {4} end)()function rtk.Window.static._make_icons()local w,h=12,12
local sz=2
local icon=rtk.Image(w,h)icon:pushdest()rtk.color.set(rtk.theme.dark and {1,1,1,1} or {0,0,0,1})for row=0,2 do
for col=0,2 do
local n=row*3+col
if n==2 or n>=4 then
gfx.rect(2*col*sz,2*row*sz,sz,sz,1)end
end
end
icon:popdest()rtk.Window.static._icon_resize_grip=icon
end
rtk.Window.register{x=rtk.Attribute{type='number',default=rtk.Attribute.NIL,reflow=rtk.Widget.REFLOW_NONE,redraw=false,window_sync=true,},y=rtk.Attribute{type='number',default=rtk.Attribute.NIL,reflow=rtk.Widget.REFLOW_NONE,redraw=false,window_sync=true,},w=rtk.Attribute{priority=true,type='number',window_sync=true,reflow_uses_exterior_value=true,animate=function(self,anim)return rtk.Widget.attributes.w.animate(self,anim,rtk.scale.framebuffer)end,calculate=function(self,attr,value,target)return value and value*rtk.scale.framebuffer or target[attr]
end,},h=rtk.Attribute{priority=true,type='number',window_sync=true,reflow_uses_exterior_value=true,animate=rtk.Reference('w'),calculate=rtk.Reference('w'),},minw=rtk.Attribute{default=100,window_sync=true,reflow_uses_exterior_value=true,},minh=rtk.Attribute{default=30,window_sync=true,reflow_uses_exterior_value=true,},maxw=rtk.Attribute{window_sync=true,reflow_uses_exterior_value=true,},maxh=rtk.Attribute{window_sync=true,reflow_uses_exterior_value=true,},visible=rtk.Attribute{window_sync=true,},docked=rtk.Attribute{default=false,window_sync=true,reflow=rtk.Widget.REFLOW_NONE,},dock=rtk.Attribute{default=rtk.Window.DOCK_RIGHT,calculate={bottom=rtk.Window.DOCK_BOTTOM,left=rtk.Window.DOCK_LEFT,top=rtk.Window.DOCK_TOP,right=rtk.Window.DOCK_RIGHT,floating=rtk.Window.DOCK_FLOATING
},window_sync=true,reflow=rtk.Widget.REFLOW_NONE,},pinned=rtk.Attribute{default=false,window_sync=true,calculate=function(self,attr,value,target)return rtk.has_js_reascript_api and value
end,},borderless=rtk.Attribute{default=false,window_sync=true,calculate=rtk.Reference('pinned')},title=rtk.Attribute{default='REAPER application',reflow=rtk.Widget.REFLOW_NONE,window_sync=true,redraw=false,},opacity=rtk.Attribute{default=1.0,reflow=rtk.Widget.REFLOW_NONE,window_sync=true,redraw=false,},resizable=rtk.Attribute{default=true,reflow=rtk.Widget.REFLOW_NONE,window_sync=true,},hwnd=nil,in_window=false,is_focused=not rtk.has_js_reascript_api and true or false,running=false,cursor=rtk.mouse.cursors.POINTER,scalability=rtk.Widget.BOX,}function rtk.Window:initialize(attrs,...)rtk.Container.initialize(self,attrs,self.class.attributes.defaults,...)rtk.window=self
self.window=self
if self.id==0 and self.calc.bg and rtk.theme.default then
rtk.set_theme_by_bgcolor(self.calc.bg)end
if rtk.Window.static._icon_resize_grip==nil then
rtk.Window._make_icons()end
if not rtk.has_js_reascript_api then
self:sync('borderless', false)self:sync('pinned', false)end
self._dockstate=0
self._backingstore=rtk.Image()self._event=rtk.Event()self._reflow_queued=false
self._reflow_widgets=nil
self._blits_queued=0
self._draw_queued=false
self._mouse_refresh_queued=false
self._sync_window_attrs_on_update=true
self._resize_grip=nil
self._move_grip=nil
self._os_window_frame_width=0
self._os_window_frame_height=0
self._undocked_geometry=nil
self._unmaximized_geometry=nil
self._last_mousemove_time=nil
self._last_mouseup_time=0
self._touch_scrolling={count=0}self._last_synced_attrs={}end
function rtk.Window:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ok=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if attr=='bg' then
local color=rtk.color.int(value or rtk.theme.bg)gfx.clear=color
if rtk.has_js_reascript_api then
if self._gdi_brush then
reaper.JS_GDI_DeleteObject(self._gdi_brush)reaper.JS_GDI_DeleteObject(self._gdi_pen)else
reaper.atexit(function()reaper.JS_GDI_DeleteObject(self._gdi_brush)reaper.JS_GDI_DeleteObject(self._gdi_pen)end)end
color=rtk.color.flip_byte_order(color)self._gdi_brush=reaper.JS_GDI_CreateFillBrush(color)self._gdi_pen=reaper.JS_GDI_CreatePen(1,color)end
end
if self.class.attributes.get(attr).window_sync and not sync then
self._sync_window_attrs_on_update=true
end
return true
end
function rtk.Window:_get_dockstate_from_attrs()local calc=self.calc
local dock=calc.dock
if type(dock)=='table' then
dock=self:_get_docker_at_pos(dock[1])end
local dockstate=(dock or 0)<<8
if calc.docked and calc.docked~=0 then
dockstate=dockstate|1
end
return dockstate
end
function rtk.Window:_get_docker_at_pos(pos)if not reaper.DockGetPosition then
return 0
end
for i=1,20 do
if reaper.DockGetPosition(i)==pos then
return i
end
end
end
function rtk.Window:_clear_gdi(startw,starth)if not rtk.os.windows or not rtk.has_js_reascript_api or not self.hwnd then
return
end
local calc=self.calc
local dc=reaper.JS_GDI_GetWindowDC(self.hwnd)reaper.JS_GDI_SelectObject(dc,self._gdi_brush)reaper.JS_GDI_SelectObject(dc,self._gdi_pen)local x=0
local y=0
local r,w,h=reaper.JS_Window_GetClientSize(self.hwnd)if not startw then
reaper.JS_GDI_FillRect(dc,x,y,w*2,h*2)elseif w>startw or h>starth then
if not calc.docked and not calc.borderless then
startw=startw+self._os_window_frame_width
starth=starth+self._os_window_frame_height
end
reaper.JS_GDI_FillRect(dc,x+math.round(startw),y,w*2,h*2)reaper.JS_GDI_FillRect(dc,x,y+math.round(starth),w*2,h*2)end
reaper.JS_GDI_ReleaseDC(self.hwnd,dc)end
function rtk.Window:focus()if self.hwnd and rtk.has_js_reascript_api then
reaper.JS_Window_SetFocus(self.hwnd)self:queue_draw()return true
else
return false
end
end
function rtk.Window:_run()self:_update()if self.running then
rtk.defer(self._run,self)end
self._run_queued=self.running
end
function rtk.Window:_get_display_resolution(working,frame)local x=math.floor(self.x or 0)local y=math.floor(self.y or 0)local w=math.floor(x+(self.w or 1))local h=math.floor(y+(self.h or 1))local l,t,r,b=reaper.my_getViewport(0,0,0,0,x,y,w,h,working and 1 or 0)local sw=r-l
local sh=math.abs(b-t)if frame then
local borderless=self.calc.borderness
sw=sw-(borderless and 0 or self._os_window_frame_width)sh=sh-(borderless and 0 or self._os_window_frame_height)end
return l,t,sw,sh
end
function rtk.Window:_get_relative_size_from_display(w,h)local sz=w or h
if sz>0 and sz<=1.0 then
local _,_,sw,sh=self:_get_display_resolution(true,not self.calc.borderless)return w and sw*w or sh*h
else
return sz
end
end
function rtk.Window:_get_geometry_from_attrs(overrides)overrides=overrides or {}local scale=rtk.scale.framebuffer or 1
local minw,maxw,minh,maxh,sx,sy,sw,sh=self:_get_min_max_sizes()if not sh then
sx,sy,sw,sh=self:_get_display_resolution(true,not self.calc.borderless)end
local calc=self.calc
local x=self.x
local y=self.y
if not x then
x=0
overrides.halign=overrides.halign or rtk.Widget.CENTER
end
if not y then
y=0
overrides.valign=overrides.valign or rtk.Widget.CENTER
end
local w=rtk.isrel(self.w)and(self.w*sw)or(calc.w/scale)local h=rtk.isrel(self.h)and(self.h*sh)or(calc.h/scale)w=rtk.clamp(w,minw and minw/scale,maxw and maxw/scale)h=rtk.clamp(h,minh and minh/scale,maxh and maxh/scale)if sw and sh then
if overrides.halign==rtk.Widget.LEFT then
x=sx
elseif overrides.halign==rtk.Widget.CENTER then
x=sx+(overrides.x or 0)+(sw-w)/2
elseif overrides.halign==rtk.Widget.RIGHT then
x=sx+(overrides.x or 0)+(sw-w)end
if rtk.os.mac then
if overrides.valign==rtk.Widget.TOP then
y=sy+(overrides.y or 0)+(sh-h)elseif overrides.valign==rtk.Widget.CENTER then
y=sy+(overrides.y or 0)+(sh-h)/2
elseif overrides.valign==rtk.Widget.BOTTOM then
y=sy+(overrides.y or 0)end
else
if overrides.valign==rtk.Widget.TOP then
y=sy
elseif overrides.valign==rtk.Widget.CENTER then
y=sy+(overrides.y or 0)+(sh-h)/2
elseif overrides.valign==rtk.Widget.BOTTOM then
y=sy+(overrides.y or 0)+(sh-h)end
end
if overrides.constrain then
x=rtk.clamp(x,sx,sx+sw-w)y=rtk.clamp(y,sy,sy+sh-h)w=rtk.clamp(w,self.minw or 0,sw-(x-sx))h=rtk.clamp(h,self.minh or 0,sh-(rtk.os.mac and y-sy-h or y-sy))end
end
return math.round(x),math.round(y),math.round(w),math.round(h)end
function rtk.Window:_sync_window_attrs(overrides)local calc=self.calc
local lastw,lasth=self.w,self.h
local resized
local dockstate=self:_get_dockstate_from_attrs()if not rtk.has_js_reascript_api or not self.hwnd then
if dockstate~=self._dockstate then
gfx.dock(dockstate)self:_handle_dock_change(dockstate)self:onresize(lastw,lasth)return 1
else
return 0
end
end
if not self.w or not self.h then
self:reflow(rtk.Widget.REFLOW_FULL)end
if dockstate~=self._dockstate then
gfx.dock(dockstate)local r,w,h=reaper.JS_Window_GetClientSize(self.hwnd)self:_handle_dock_change(dockstate)if calc.docked then
gfx.w,gfx.h=w,h
self:sync('w', w / rtk.scale.framebuffer, w)self:sync('h', h / rtk.scale.framebuffer, h)end
self:onresize(lastw,lasth)return 1
end
if self._resize_grip then
self._resize_grip:attr('visible', calc.borderless and calc.resizable and not calc.docked)end
if not calc.docked then
if not calc.visible then
reaper.JS_Window_Show(self.hwnd, 'HIDE')return 0
end
local style='SYSMENU,DLGSTYLE,BORDER,CAPTION'if calc.resizable then
style=style .. ',THICKFRAME'end
if calc.borderless then
style='POPUP'self:_setup_borderless()if not self.realized then
local sw=math.ceil(self.calc.w/rtk.scale.framebuffer)local sh=math.ceil(self.calc.h/rtk.scale.framebuffer)reaper.JS_Window_Resize(self.hwnd,sw,sh)end
end
local function restyle()reaper.JS_Window_SetStyle(self.hwnd,style)if rtk.os.bits~=32 then
local n=reaper.JS_Window_GetLong(self.hwnd, 'STYLE')reaper.JS_Window_SetLong(self.hwnd, 'STYLE', n | 0x80000000)end
reaper.JS_Window_SetZOrder(self.hwnd, calc.pinned and 'TOPMOST' or 'NOTOPMOST')local r,x1,y1,x2,y2=reaper.JS_Window_GetRect(self.hwnd)if r then
reaper.JS_Window_Resize(self.hwnd,x2-x1,y2-y1)self:_discover_os_window_frame_size(self.hwnd)end
end
if reaper.JS_Window_IsVisible(self.hwnd)then
restyle()else
rtk.defer(restyle)end
local x,y,w,h=self:_get_geometry_from_attrs(overrides)local scaled_gfxw=gfx.w/rtk.scale.framebuffer
local scaled_gfxh=gfx.h/rtk.scale.framebuffer
if not resized then
if w==scaled_gfxw and h==scaled_gfxh then
resized=0
elseif w<=scaled_gfxw and h<=scaled_gfxh then
resized=-1
elseif w>scaled_gfxw or h>scaled_gfxh then
resized=1
end
end
local r,lastx,lasty,x2,y2=reaper.JS_Window_GetClientRect(self.hwnd)local moved=r and(self.x~=lastx or self.y~=lasty)local borderless_toggled=calc.borderless~=self._last_synced_attrs.borderless
if moved or resized~=0 or borderless_toggled then
local sw,sh=w,h
if not calc.borderless then
sw=w+self._os_window_frame_width
sh=h+self._os_window_frame_height
end
sw=math.ceil(sw)sh=math.ceil(sh)reaper.JS_Window_SetPosition(self.hwnd,x,y,sw,sh)end
if resized~=0 then
gfx.w=w*rtk.scale.framebuffer
gfx.h=h*rtk.scale.framebuffer
self:queue_blit()self:onresize(scaled_gfxw,scaled_gfxh)end
if moved then
self:sync('x', x, 0)self:sync('y', y, 0)self:onmove(lastx,lasty)end
reaper.JS_Window_SetOpacity(self.hwnd, 'ALPHA', calc.opacity)reaper.JS_Window_SetTitle(self.hwnd,calc.title)else
local flags=reaper.JS_Window_GetLong(self.hwnd, 'EXSTYLE')flags=flags&~0x00080000
reaper.JS_Window_SetLong(self.hwnd, 'EXSTYLE', flags)end
self._last_synced_attrs.borderless=calc.borderless
return resized or 0
end
function rtk.Window:open(options)if self.running or rtk._quit then
return
end
local calc=self.calc
rtk.window=self
if options then
options.halign=options.halign or options.align
options.valign=options.valign or options.align
end
if not calc.borderless and self._os_window_frame_width==0 then
self:_discover_os_window_frame_size(rtk.reaper_hwnd)end
if not self.w or not self.h then
self:reflow(rtk.Widget.REFLOW_FULL)end
self.running=true
gfx.ext_retina=1
self:_handle_attr('bg', calc.bg or rtk.theme.bg)options=self:_calc_cell_attrs(self,options)local x,y,w,h=self:_get_geometry_from_attrs(options)self:sync('x', x, 0)self:sync('y', y, 0)self:sync('w', w)self:sync('h', h)local dockstate=self:_get_dockstate_from_attrs()gfx.init(calc.title,calc.w/rtk.scale.framebuffer,calc.h/rtk.scale.framebuffer,dockstate,x,y)gfx.update()if gfx.ext_retina==2 and rtk.os.mac and rtk.scale.framebuffer~=2 then
log.warning('rtk.Window:open(): unexpected adjustment to rtk.scale.framebuffer: %s -> 2', rtk.scale.framebuffer)rtk.scale.framebuffer=2
calc.w=calc.w*rtk.scale.framebuffer
calc.h=calc.h*rtk.scale.framebuffer
end
dockstate,_,_=gfx.dock(-1,true,true)self:_handle_dock_change(dockstate)if rtk.has_js_reascript_api then
self:_clear_gdi()else
rtk.color.set(rtk.theme.bg)gfx.rect(0,0,w,h,1)end
self._draw_queued=true
if not self._run_queued then
self:_run()end
end
function rtk.Window:_close()self.running=false
gfx.quit()end
function rtk.Window:close()local event=rtk.Event{type=rtk.Event.WINDOWCLOSE}self:_handle_window_event(event,reaper.time_precise())self.hwnd=nil
self:_close()self:onclose()end
function rtk.Window:_setup_borderless()if self._move_grip then
return
end
local calc=self.calc
local move=rtk.Spacer{z=-10000,w=1.0,h=30,touch_activate_delay=0}move.onmousedown=function(this,event)if not calc.docked and calc.borderless then
local _,wx,wy,_,_=reaper.JS_Window_GetClientRect(self.hwnd)local mx,my=reaper.GetMousePosition()this._drag_start_mx=mx
this._drag_start_my=my
this._drag_start_wx=wx
this._drag_start_wy=wy
this._drag_start_ww=gfx.w/rtk.scale.framebuffer
this._drag_start_wh=gfx.h/rtk.scale.framebuffer
this._drag_start_dx=mx-wx
this._drag_start_dy=my-wy
end
return true
end
move.ondragstart=function(this,event)if not calc.docked and calc.borderless and this._drag_start_mx then
return true
else
return false
end
end
move.ondragend=function(this,event)this._drag_start_mx=nil
end
move.ondragmousemove=function(this,event)local _,wx,wy,_,wy2=reaper.JS_Window_GetClientRect(self.hwnd)local mx,my=reaper.GetMousePosition()local x=mx-this._drag_start_dx
local y
if rtk.os.mac then
local h=wy-wy2
y=my-this._drag_start_dy-h
else
y=my-this._drag_start_dy
end
if self._unmaximized_geometry then
local _,_,w,h=table.unpack(self._unmaximized_geometry)local sx,_,sw,sh=self:_get_display_resolution()local xoffset=event.x/rtk.scale.framebuffer
local dx=math.ceil(w*xoffset/this._drag_start_ww)x=rtk.clamp(sx+xoffset-dx,sx,sx+sw-w)self._unmaximized_geometry=nil
this._drag_start_ww=w
this._drag_start_wh=h
this._drag_start_dx=dx
if rtk.os.mac then
y=(wy-h)+(my-this._drag_start_my)end
reaper.JS_Window_SetPosition(self.hwnd,x,y,w,h)else
reaper.JS_Window_Move(self.hwnd,x,y)end
end
move.ondoubleclick=function(this,event)if calc.docked or not calc.borderless then
return
end
local x,y,w,h=self:_get_display_resolution(true)if self._unmaximized_geometry then
if math.abs(w-self.w)<w*0.05 and math.abs(h-self.h)<h*0.05 then
x,y,w,h=table.unpack(self._unmaximized_geometry)end
self._unmaximized_geometry=nil
else
self._unmaximized_geometry={self.x,self.y,self.w,self.h}end
self:move(x,y)self:resize(w,h)return true
end
local resize=rtk.ImageBox{image=rtk.Window._icon_resize_grip,z=10000,visible=calc.resizable,cursor=rtk.mouse.cursors.SIZE_NW_SE,alpha=0.4,autofocus=true,touch_activate_delay=0,tooltip='Resize window',bmargin=-(calc.bpadding or 0),rmargin=-(calc.rpadding or 0),}resize.onmouseenter=function(this)if calc.borderless then
this:animate{attr='alpha', dst=1, duration=0.1}return true
end
end
resize.onmouseleave=function(this,event)if calc.borderless then
this:animate{attr='alpha', dst=0.4, duration=0.25}end
end
resize.onmousedown=move.onmousedown
resize.ondragstart=move.ondragstart
resize.ondragmousemove=function(this,event)local _,ww,wh=reaper.JS_Window_GetClientSize(self.hwnd)local mx,my=reaper.GetMousePosition()local dx=mx-this._drag_start_mx
local dy=(my-this._drag_start_my)*(rtk.os.mac and-1 or 1)local w=math.max(self.minw or 0,this._drag_start_ww+dx)local h=math.max(self.minh or 0,this._drag_start_wh+dy)reaper.JS_Window_Resize(self.hwnd,w,h)self:_clear_gdi(calc.w,calc.h)if rtk.os.mac then
reaper.JS_Window_Move(self.hwnd,this._drag_start_wx,this._drag_start_wy-h)end
end
self:add(move)self:add(resize, {valign='bottom', halign='right'})self._move_grip=move
self._resize_grip=resize
end
local function verify_hwnd_coords(hwnd,x,y)local _,hx,hy,_,_=reaper.JS_Window_GetClientRect(hwnd)return hx==x and hy==y
end
local function search_hwnd_addresses(list,title,x,y)for _,addr in ipairs(list)do
addr=tonumber(addr)if addr then
local hwnd=reaper.JS_Window_HandleFromAddress(addr)if(not title or reaper.JS_Window_GetTitle(hwnd)==title)and verify_hwnd_coords(hwnd,x,y)then
return hwnd
end
end
end
end
function rtk.Window:_discover_os_window_frame_size(hwnd)if not reaper.JS_Window_GetClientSize then
return
end
local _,w,h=reaper.JS_Window_GetClientSize(hwnd)local _,l,t,r,b=reaper.JS_Window_GetRect(hwnd)self._os_window_frame_width=(r-l)-w
self._os_window_frame_height=math.abs(b-t)-h
self._os_window_frame_width=self._os_window_frame_width
self._os_window_frame_height=self._os_window_frame_height
end
function rtk.Window:_get_hwnd()if not rtk.has_js_reascript_api then
return
end
local x,y=gfx.clienttoscreen(0,0)local title=self.calc.title
local hwnd=reaper.JS_Window_Find(title,true)if hwnd and not verify_hwnd_coords(hwnd,x,y)then
hwnd=nil
if self.calc.docked then
local _,addrs=reaper.JS_Window_ListAllChild(rtk.reaper_hwnd)hwnd=search_hwnd_addresses((addrs or ''):split(','), title, x, y)end
if not hwnd then
log.time_start()local a=reaper.new_array({},50)reaper.JS_Window_ArrayFind(title,true,a)hwnd=search_hwnd_addresses(a.table(),nil,x,y)log.time_end('rtk.Window:_get_hwnd(): needed to take slow path: title=%s', title)end
end
if hwnd then
self:_discover_os_window_frame_size(hwnd)end
return hwnd
end
function rtk.Window:_handle_dock_change(dockstate)local calc=self.calc
local was_docked=(self._dockstate&0x01)~=0
calc.docked=dockstate&0x01~=0
calc.dock=(dockstate>>8)&0xff
self:sync('dock', calc.dock)self:sync('docked', calc.docked)self._dockstate=dockstate
self.hwnd=self:_get_hwnd()self:queue_reflow(rtk.Widget.REFLOW_FULL)if was_docked~=calc.docked then
self:_clear_gdi()if calc.docked then
self._undocked_geometry={self.x,self.y,self.w,self.h}elseif self._undocked_geometry then
local x,y,w,h=table.unpack(self._undocked_geometry)local gw=w*rtk.scale.framebuffer
local gh=h*rtk.scale.framebuffer
self:sync('x', x, 0)self:sync('y', y, 0)self:sync('w', w, gw)self:sync('h', h, gh)gfx.w=gw
gfx.h=gh
end
end
self:_sync_window_attrs()self:queue_blit()self:ondock()end
function rtk.Window:queue_reflow(mode,widget)if mode~=rtk.Widget.REFLOW_FULL and widget and widget.box then
if self._reflow_widgets then
self._reflow_widgets[widget]=true
elseif not self._reflow_queued then
self._reflow_widgets={[widget]=true}end
else
self._reflow_widgets=nil
end
self._reflow_queued=true
end
function rtk.Window:queue_draw()self._draw_queued=true
end
function rtk.Window:queue_blit()self._blits_queued=self._blits_queued+2
end
function rtk.Window:queue_mouse_refresh()self._mouse_refresh_queued=true
end
function rtk.Window:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,scale,greedyw,greedyh)local calc=self.calc
local tp,rp,bp,lp=self:_get_padding_and_border()local w=rtk.isrel(self.w)and(self.w*boxw)or(self.w and(calc.w-lp-rp))or nil
local h=rtk.isrel(self.h)and(self.h*boxh)or(self.h and(calc.h-tp-bp))or nil
local minw,maxw,minh,maxh=self:_get_min_max_sizes(boxw,boxh,greedyw,greedyh,scale)return w,h,tp,rp,bp,lp,minw,maxw,minh,maxh
end
function rtk.Window:_get_min_max_sizes(boxw,boxh,greedyw,greedyh,scale)if not self._sync_window_attrs_on_update then
return
end
local calc=self.calc
local sx,sy,sw,sh=self:_get_display_resolution(true,not calc.borderless)scale=rtk.scale.framebuffer
local minw,maxw,minh,maxh=rtk.Container._get_min_max_sizes(self,sw*scale,sh*scale,true,true,scale)return minw,maxw,minh,maxh,sx,sy,sw,sh
end
function rtk.Window:_reflow(boxx,boxy,boxw,boxh,fillw,filly,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
rtk.Container._reflow(self,boxx,boxy,boxw,boxh,fillw,filly,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)calc.x=0
calc.y=0
end
function rtk.Window:reflow(mode)local calc=self.calc
local widgets=self._reflow_widgets
local full=false
self._reflow_queued=false
self._reflow_widgets=nil
local t0=reaper.time_precise()if mode~=rtk.Widget.REFLOW_FULL and widgets and self.realized and #widgets<20 then
for widget,_ in pairs(widgets)do
widget:reflow()widget:_realize_geometry()end
else
if #self.children==0 then
calc.w=self.w and calc.w or calc.minw
calc.h=self.h and calc.h or calc.minh
else
local saved_size
local boxw,boxh=calc.w,calc.h
if not self.w or not self.h or rtk.isrel(self.w)or rtk.isrel(self.h)then
local _,_,sw,sh=self:_get_display_resolution(true,not calc.borderless)boxw=(rtk.isrel(self.w)or not self.w)and sw*rtk.scale.framebuffer or boxw
boxh=(rtk.isrel(self.h)or not self.h)and sh*rtk.scale.framebuffer or boxh
end
local _,_,w,h=rtk.Container.reflow(self,0,0,boxw,boxh,nil,nil,true,true,rtk.scale.value,nil,self,self.w~=nil,self.h~=nil
)self:_realize_geometry()full=true
end
end
local reflow_time=reaper.time_precise()-t0
if reflow_time>0.02 then
log.warning("rtk: slow reflow: %s", reflow_time)end
self:onreflow(widgets)self._draw_queued=true
return full
end
function rtk.Window:_get_mouse_button_event(bit,type)if not type then
if rtk.mouse.down&bit==0 and gfx.mouse_cap&bit~=0 then
rtk.mouse.down=rtk.mouse.down|bit
type=rtk.Event.MOUSEDOWN
elseif rtk.mouse.down&bit~=0 and gfx.mouse_cap&bit==0 then
rtk.mouse.down=rtk.mouse.down&~bit
type=rtk.Event.MOUSEUP
end
end
if type then
local event=self._event:reset(type)event.x,event.y=gfx.mouse_x,gfx.mouse_y
event:set_modifiers(gfx.mouse_cap,bit)return event
end
end
function rtk.Window:_get_mousemove_event(simulated)local event=self._event:reset(rtk.Event.MOUSEMOVE)event.simulated=simulated
event:set_modifiers(gfx.mouse_cap,rtk.mouse.state.latest or 0)return event
end
local function _get_wheel_distance(v)if rtk.os.mac then
return-v/90
else
return-v/120
end
end
function rtk.Window:_update()rtk.tick=rtk.tick+1
local calc=self.calc
local now=reaper.time_precise()local need_draw=false
if gfx.ext_retina~=rtk.scale.system then
rtk.scale.system=gfx.ext_retina
rtk.scale._calc()self:queue_reflow()end
local files=nil
local _,fname=gfx.getdropfile(0)if fname then
files={fname}local idx=1
while true do
_,fname=gfx.getdropfile(idx)if not fname then
break
end
files[#files+1]=fname
idx=idx+1
end
gfx.getdropfile(-1)end
gfx.update()if rtk._soon_funcs then
rtk._run_soon()end
local focus_changed=false
if rtk.has_js_reascript_api then
rtk.focused_hwnd=reaper.JS_Window_GetFocus()local is_focused=self.hwnd==rtk.focused_hwnd
if is_focused~=self.is_focused then
self.is_focused=is_focused
need_draw=true
focus_changed=true
end
end
if self:onupdate()==false then
return
end
need_draw=rtk._do_animations(now)or need_draw
if self._sync_window_attrs_on_update then
if self:_sync_window_attrs()~=0 then
self:reflow(rtk.Widget.REFLOW_FULL)need_draw=true
end
self._sync_window_attrs_on_update=false
end
local dockstate,x,y=gfx.dock(-1,true,true)local dock_changed=dockstate~=self._dockstate
if dock_changed then
self:_handle_dock_change(dockstate)end
if x~=self.x or y~=self.y then
local lastx,lasty=self.x,self.y
self:sync('x', x, 0)self:sync('y', y, 0)self:onmove(lastx,lasty)end
local resized=gfx.w~=calc.w or gfx.h~=calc.h
if resized and self.visible then
local last_w,last_h=self.w,self.h
self:sync('w', gfx.w / rtk.scale.framebuffer, gfx.w)self:sync('h', gfx.h / rtk.scale.framebuffer, gfx.h)self:_clear_gdi(calc.w,calc.h)self:onresize(last_w,last_h)self:reflow(rtk.Widget.REFLOW_FULL)need_draw=true
elseif self._reflow_queued then
self:reflow()need_draw=true
end
local event=nil
calc.cursor=rtk.mouse.cursors.UNDEFINED
if gfx.mouse_wheel~=0 or gfx.mouse_hwheel~=0 then
event=self._event:reset(rtk.Event.MOUSEWHEEL)event:set_modifiers(gfx.mouse_cap,0)event.wheel=_get_wheel_distance(gfx.mouse_wheel)event.hwheel=_get_wheel_distance(gfx.mouse_hwheel)self:onmousewheel(event)gfx.mouse_wheel=0
gfx.mouse_hwheel=0
self:_handle_window_event(event,now)end
local keycode=gfx.getchar()if keycode>0 then
while keycode>0 do
event=self._event:reset(rtk.Event.KEY)event:set_modifiers(gfx.mouse_cap,0)event:set_keycode(keycode)self:onkeypresspre(event)self:_handle_window_event(event,now)self:onkeypresspost(event)if not event.handled then
if event.keycode==rtk.keycodes.F12 and log.level<=log.DEBUG then
rtk.debug=not rtk.debug
self:queue_draw()elseif event.keycode==rtk.keycodes.ESCAPE and not self.docked then
self:close()end
end
keycode=gfx.getchar()end
elseif keycode<0 then
self:close()end
if files then
event=self:_get_mousemove_event(false)event.type=rtk.Event.DROPFILE
event.files=files
self:_handle_window_event(event,now)end
rtk._touch_activate_event=rtk.touchscroll and rtk.Event.MOUSEUP or rtk.Event.MOUSEDOWN
local mouse_button_changed=(rtk.mouse.down~=gfx.mouse_cap&rtk.mouse.BUTTON_MASK)local buttons_down=(gfx.mouse_cap&rtk.mouse.BUTTON_MASK~=0)local mouse_moved=(rtk.mouse.x~=gfx.mouse_x or rtk.mouse.y~=gfx.mouse_y)local last_in_window=self.in_window
self.in_window=gfx.mouse_x>=0 and gfx.mouse_y>=0 and gfx.mouse_x<=gfx.w and gfx.mouse_y<=gfx.h
local in_window_changed=self.in_window~=last_in_window
need_draw=need_draw or self._draw_queued or in_window_changed
if self._last_mousemove_time and rtk._mouseover_widget and
rtk._mouseover_widget~=self._tooltip_widget and
now-self._last_mousemove_time>rtk.tooltip_delay then
self._tooltip_widget=rtk._mouseover_widget
need_draw=true
end
if mouse_button_changed and rtk.touchscroll and self._jsx then
self._restore_mouse_pos={self._jsx,self._jsy,nil}end
if mouse_moved then
if self.in_window then
self._jsx=nil
elseif not buttons_down then
self._jsx,self._jsy=reaper.GetMousePosition()end
if self._mouse_refresh_queued then
self._mouse_refresh_queued=false
local tmp=self:_get_mousemove_event(true)tmp.buttons=0
tmp.button=0
self:_handle_window_event(tmp,now)need_draw=true
end
end
local suppress=false
if not event or mouse_moved then
if self.in_window and rtk.has_js_reascript_api and self.hwnd then
local x,y=reaper.GetMousePosition()local hwnd=reaper.JS_Window_FromPoint(x,y)if hwnd~=self.hwnd then
self.in_window=false
in_window_changed=last_in_window~=false
end
end
if need_draw or(mouse_moved and self.in_window)or in_window_changed or
(rtk.dnd.dragging and buttons_down)then
event=self:_get_mousemove_event(not mouse_moved)if buttons_down and rtk.touchscroll and not rtk.dnd.dragging then
suppress=not event:get_button_state('mousedown-handled')end
elseif rtk.mouse.down~=0 and not mouse_button_changed then
local buttonstate=rtk.mouse.state[rtk.mouse.state.latest]
local wait=math.max(rtk.long_press_delay,rtk.touch_activate_delay)if now-buttonstate.time<=wait+(2/rtk.fps)then
event=self:_get_mouse_button_event(rtk.mouse.state.latest,rtk.Event.MOUSEDOWN)event.simulated=true
end
end
if event and(not event.simulated or self._touch_scrolling.count==0 or buttons_down)then
need_draw=need_draw or self._tooltip_widget~=nil
self:_handle_window_event(event,now,suppress)end
end
rtk.mouse.x=gfx.mouse_x
rtk.mouse.y=gfx.mouse_y
if mouse_button_changed then
event=self:_get_mouse_button_event(rtk.mouse.BUTTON_LEFT)if not event then
event=self:_get_mouse_button_event(rtk.mouse.BUTTON_RIGHT)if not event then
event=self:_get_mouse_button_event(rtk.mouse.BUTTON_MIDDLE)end
end
if event then
if event.type==rtk.Event.MOUSEDOWN then
local buttonstate=rtk.mouse.state[event.button]
if not buttonstate then
buttonstate={}rtk.mouse.state[event.button]=buttonstate
end
buttonstate.time=now
buttonstate.tick=rtk.tick
rtk.mouse.state.order[#rtk.mouse.state.order+1]=event.button
rtk.mouse.state.latest=event.button
elseif event.type==rtk.Event.MOUSEUP then
if rtk.touchscroll and event.buttons==0 and self._restore_mouse_pos then
self._restore_mouse_pos[3]=now+0.2
end
end
self:_handle_window_event(event,now)else
log.warning('rtk: no event for mousecap=%s which indicates an internal rtk bug', gfx.mouse_cap)end
end
if rtk._soon_funcs then
rtk._run_soon()end
local blitted=false
if event and calc.visible then
if need_draw or self._draw_queued and not self._sync_window_attrs_on_update then
if self._reflow_queued then
if self:reflow()then
calc.cursor=rtk.mouse.cursors.UNDEFINED
local tmp=event:clone{type=rtk.Event.MOUSEMOVE,simulated=true}self:_handle_window_event(tmp,now)end
end
self._backingstore:resize(calc.w,calc.h,false)self._backingstore:pushdest()self:clear()self._draw_queued=false
self:_draw(0,0,calc.alpha,event,calc.w,calc.h,0,0,0,0)if event.debug then
event.debug:_draw_debug_info(event)end
if self._tooltip_widget and not rtk.dnd.dragging then
self._tooltip_widget:_draw_tooltip(rtk.mouse.x,rtk.mouse.y,calc.w,calc.h)end
self._backingstore:popdest()self:_blit()blitted=true
end
if focus_changed then
if self.is_focused then
if self._focused_saved then
self._focused_saved:focus(event)self._focused_saved=nil
end
self:onfocus(event)else
if rtk.focused then
self._focused_saved=rtk.focused
rtk.focused:blur(event,nil)end
self:onblur(event)end
end
if not event.handled and rtk.is_modal()and
((focus_changed and not self.is_focused)or event.type==rtk._touch_activate_event)then
for _,info in pairs(rtk._modal)do
local widget,modaltick=table.unpack(info)local state=rtk.mouse.state[event.button]
if not state or(modaltick~=state.modaltick)then
widget:_release_modal(event)end
end
end
if not event.handled and rtk.focused and event.type==rtk._touch_activate_event then
rtk.focused:blur(event,nil)end
if event.type==rtk.Event.MOUSEUP then
rtk.mouse.last[event.button]={x=event.x,y=event.y}for i=1,#rtk.mouse.state.order do
if rtk.mouse.state.order[i]==event.button then
table.remove(rtk.mouse.state.order,i)break
end
end
if #rtk.mouse.state.order>0 then
rtk.mouse.state.latest=rtk.mouse.state.order[#rtk.mouse.state.order]
else
rtk.mouse.state.latest=0
end
rtk.mouse.state[event.button]=nil
if event.buttons==0 then
rtk._pressed_widgets=nil
end
end
if calc.cursor==rtk.mouse.cursors.UNDEFINED then
calc.cursor=self.cursor
end
if self.in_window and not suppress then
if type(calc.cursor)=='userdata' then
reaper.JS_Mouse_SetCursor(calc.cursor)reaper.JS_WindowMessage_Intercept(self.hwnd, "WM_SETCURSOR", false)else
gfx.setcursor(calc.cursor,0)end
elseif in_window_changed and self.hwnd and rtk.has_js_reascript_api then
reaper.JS_WindowMessage_Release(self.hwnd, "WM_SETCURSOR")end
end
if self._restore_mouse_pos and not buttons_down then
local x,y,when=table.unpack(self._restore_mouse_pos)if when and now>=when then
reaper.JS_Mouse_SetPosition(x,y)self._restore_mouse_pos=nil
end
end
if mouse_moved then
self._last_mousemove_time=now
end
if self._blits_queued>0 then
if not blitted then
self:_blit()end
self._blits_queued=self._blits_queued-1
end
local duration=reaper.time_precise()-now
if duration>0.04 then
log.debug("rtk: very slow update: %s  event=%s", duration, event)end
end
function rtk.Window:_blit()self._backingstore:blit{mode=rtk.Image.FAST_BLIT}end
function rtk.Window:_handle_window_event(event,now,suppress)if not self.calc.visible then
return
end
if not event.simulated then
rtk._mouseover_widget=nil
self._tooltip_widget=nil
self._last_mousemove_time=nil
end
event.time=now
if not suppress then
self:_handle_event(0,0,event,false,rtk._modal==nil)end
assert(event.type~=rtk.Event.MOUSEDOWN or event.button~=0)if event.type==rtk.Event.MOUSEUP then
self._last_mouseup_time=event.time
rtk._drag_candidates=nil
if rtk.dnd.dropping then
rtk.dnd.dropping:_handle_dropblur(event,rtk.dnd.dragging,rtk.dnd.arg)rtk.dnd.dropping=nil
end
if rtk.dnd.dragging and event.buttons&rtk.dnd.buttons==0 then
rtk.dnd.dragging:_handle_dragend(event,rtk.dnd.arg)rtk.dnd.dragging=nil
rtk.dnd.arg=nil
local tmp=event:clone{type=rtk.Event.MOUSEMOVE,simulated=true}rtk.Container._handle_event(self,0,0,tmp,false,rtk._modal==nil)end
elseif rtk._drag_candidates and event.type==rtk.Event.MOUSEMOVE and
not event.simulated and event.buttons~=0 and not rtk.dnd.arg then
event.handled=nil
rtk.dnd.droppable=true
local missed=false
local dthresh=math.ceil(rtk.scale.value ^ 1.7)if rtk.touchscroll and event.time-self._last_mouseup_time<0.2 then
dthresh=rtk.scale.value*10
end
for n,state in ipairs(rtk._drag_candidates)do
local widget,offered=table.unpack(state)if not offered then
local ex,ey,when=table.unpack(rtk._pressed_widgets[widget.id])local dx=math.abs(ex-event.x)local dy=math.abs(ey-event.y)local tthresh=widget:_get_touch_activate_delay(event)if event.time-when>=tthresh and(dx>dthresh or dy>dthresh)then
local arg,droppable=widget:_handle_dragstart(event,ex,ey,when)if arg then
widget:_deferred_mousedown(event,ex,ey)rtk.dnd.dragging=widget
rtk.dnd.arg=arg
rtk.dnd.droppable=droppable~=false and true or false
rtk.dnd.buttons=event.buttons
widget:_handle_dragmousemove(event,arg)break
elseif event.handled then
break
end
state[2]=true
else
missed=true
end
end
end
if not missed or event.handled then
rtk._drag_candidates=nil
end
end
end
function rtk.Window:request_mouse_cursor(cursor,force)if cursor and(self.calc.cursor==rtk.mouse.cursors.UNDEFINED or force)then
self.calc.cursor=cursor
return true
else
return false
end
end
function rtk.Window:clear()self._backingstore:clear(self.calc.bg or rtk.theme.bg)end
function rtk.Window:get_normalized_y()if not rtk.os.mac then
return self.y
else
local _,_,_,sh=self:_get_display_resolution()return sh-self.y-gfx.h/rtk.scale.framebuffer-self._os_window_frame_height
end
end
function rtk.Window:_set_touch_scrolling(viewport,state)local ts=self._touch_scrolling
local exists=ts[viewport.id]~=nil
if state and not exists then
ts[viewport.id]=viewport
ts.count=ts.count+1
elseif not state and exists then
ts[viewport.id]=nil
ts.count=ts.count-1
end
end
function rtk.Window:_is_touch_scrolling(viewport)if viewport then
return self._touch_scrolling[viewport.id]~=nil
else
return self._touch_scrolling.count>0
end
end
function rtk.Window:onupdate()end
function rtk.Window:onreflow(widgets)end
function rtk.Window:onmove(lastx,lasty)end
function rtk.Window:onresize(lastw,lasth)end
function rtk.Window:ondock()end
function rtk.Window:onclose()end
function rtk.Window:onkeypresspre(event)end
function rtk.Window:onkeypresspost(event)end
end)()

__mod_rtk_box=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Box=rtk.class('rtk.Box', rtk.Container)rtk.Box.static.HORIZONTAL=1
rtk.Box.static.VERTICAL=2
rtk.Box.static.FLEXSPACE={}rtk.Box.static.STRETCH_NONE=0
rtk.Box.static.STRETCH_FULL=1
rtk.Box.static.STRETCH_TO_SIBLINGS=2
rtk.Box.register{expand=rtk.Attribute{type='number'},fillw=false,fillh=false,stretch=rtk.Attribute{calculate={none=rtk.Box.STRETCH_NONE,full=rtk.Box.STRETCH_FULL,siblings=rtk.Box.STRETCH_TO_SIBLINGS,['true']=rtk.Box.STRETCH_FULL,['false']=rtk.Box.STRETCH_NONE,[true]=rtk.Box.STRETCH_FULL,[false]=rtk.Box.STRETCH_NONE,[rtk.Attribute.NIL]=rtk.Box.STRETCH_NONE,}},bg=nil,orientation=nil,spacing=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL,},}function rtk.Box:initialize(attrs,...)rtk.Container.initialize(self,attrs,self.class.attributes.defaults,...)assert(self.orientation, 'rtk.Box cannot be instantiated directly, use rtk.HBox or rtk.VBox instead')end
function rtk.Box:_validate_child(child)if child~=rtk.Box.FLEXSPACE then
rtk.Container._validate_child(self,child)end
end
function rtk.Box:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)local inner_maxw=rtk.clamp(w or(boxw-lp-rp),minw,maxw)local inner_maxh=rtk.clamp(h or(boxh-tp-bp),minh,maxh)clampw=clampw or w~=nil or fillw
clamph=clamph or h~=nil or fillh
self._reflowed_children={}self._child_index_by_id={}local innerw,innerh,expw,exph,expand_units,remaining_size,total_spacing=self:_reflow_step1(inner_maxw,inner_maxh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)if self.orientation==rtk.Box.HORIZONTAL then
expw=(expand_units>0)or expw
elseif self.orientation==rtk.Box.VERTICAL then
exph=(expand_units>0)or exph
end
innerw,innerh=self:_reflow_step2(inner_maxw,inner_maxh,innerw,innerh,clampw,clamph,expand_units,remaining_size,total_spacing,uiscale,viewport,window,greedyw,greedyh,tp,rp,bp,lp
)fillw=fillw or(self.w and tonumber(self.w)<1.0)fillh=fillh or(self.h and tonumber(self.h)<1.0)innerw=w or math.max(innerw,fillw and greedyw and inner_maxw or 0)innerh=h or math.max(innerh,fillh and greedyh and inner_maxh or 0)calc.w=math.ceil(rtk.clamp(innerw+lp+rp,minw,maxw))calc.h=math.ceil(rtk.clamp(innerh+tp+bp,minh,maxh))return expw,exph
end
function rtk.Box:_reflow_step1(w,h,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
local orientation=calc.orientation
local remaining_size,greedy
if orientation==rtk.Box.HORIZONTAL then
remaining_size=w
greedy=greedyw
else
remaining_size=h
greedy=greedyh
end
local expand_units=0
local maxw,maxh=0,0
local spacing=0
local total_spacing=0
local expw,exph=false,false
for n,widgetattrs in ipairs(self.children)do
local widget,attrs=table.unpack(widgetattrs)local wcalc=widget.calc
attrs._cellbox=nil
if widget.id then
self._child_index_by_id[widget.id]=n
end
if widget==rtk.Box.FLEXSPACE then
expand_units=expand_units+(attrs.expand or 1)spacing=0
elseif widget.visible==true then
attrs._halign=attrs.halign or calc.halign
attrs._valign=attrs.valign or calc.valign
attrs._minw=self:_adjscale(attrs.minw,uiscale,greedyw and w)attrs._maxw=self:_adjscale(attrs.maxw,uiscale,greedyw and w)attrs._minh=self:_adjscale(attrs.minh,uiscale,greedyh and h)attrs._maxh=self:_adjscale(attrs.maxh,uiscale,greedyh and h)local implicit_expand
if orientation==rtk.Box.HORIZONTAL then
implicit_expand=attrs.fillw and greedyw
else
implicit_expand=attrs.fillh and greedyh
end
attrs._calculated_expand=attrs.expand or(implicit_expand and 1)or 0
if attrs._calculated_expand==0 and implicit_expand then
log.error('rtk.Box: %s: fill=true overrides explicit expand=0: %s will be expanded', self, widget)end
if attrs._calculated_expand==0 or not greedy then
local ww,wh=0,0
local wexpw,wexph
local ctp,crp,cbp,clp=self:_get_cell_padding(widget,attrs)if orientation==rtk.Box.HORIZONTAL then
local child_maxw=rtk.clamp(remaining_size-clp-crp-spacing,attrs._minw,attrs._maxw)local child_maxh=rtk.clamp(h-ctp-cbp,attrs._minh,attrs._maxh)_,_,ww,wh,wexpw,wexph=widget:reflow(0,0,child_maxw,child_maxh,attrs.fillw and greedyw,attrs.fillh and greedyh and attrs.stretch~=rtk.Box.STRETCH_TO_SIBLINGS,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)expw=wexpw or expw
exph=wexph or exph
ww=math.max(ww,attrs._minw or 0)wh=math.max(wh,attrs._minh or 0)if wexpw and clampw and ww>=child_maxw and n<#self.children then
attrs._calculated_expand=1
end
else
local child_maxw=rtk.clamp(w-clp-crp,attrs._minw,attrs._maxw)local child_maxh=rtk.clamp(remaining_size-ctp-cbp-spacing,attrs._minh,attrs._maxh)_,_,ww,wh,wexpw,wexph=widget:reflow(0,0,child_maxw,child_maxh,attrs.fillw and greedyw and attrs.stretch~=rtk.Box.STRETCH_TO_SIBLINGS,attrs.fillh and greedyh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)expw=wexpw or expw
exph=wexph or exph
ww=math.max(ww,attrs._minw or 0)wh=math.max(wh,attrs._minh or 0)if wexph and clamph and wh>=child_maxh and n<#self.children then
attrs._calculated_expand=1
end
end
expw=expw or(attrs.fillw and greedyw)exph=exph or(attrs.fillh and greedyh)if attrs._calculated_expand==0 and wcalc.position&rtk.Widget.POSITION_INFLOW~=0 then
maxw=math.max(maxw,ww+clp+crp)maxh=math.max(maxh,wh+ctp+cbp)if orientation==rtk.Box.HORIZONTAL then
remaining_size=remaining_size-(clampw and(ww+clp+crp+spacing)or 0)else
remaining_size=remaining_size-(clamph and(wh+ctp+cbp+spacing)or 0)end
else
expand_units=expand_units+attrs._calculated_expand
end
else
expand_units=expand_units+attrs._calculated_expand
end
if orientation==rtk.Box.VERTICAL and attrs.stretch==rtk.Box.STRETCH_FULL and greedyw then
maxw=w
elseif orientation==rtk.Box.HORIZONTAL and attrs.stretch==rtk.Box.STRETCH_FULL and greedyh then
maxh=h
end
attrs._running_spacing_total=spacing
spacing=(attrs.spacing or self.spacing)*rtk.scale.value
total_spacing=total_spacing+spacing
self:_add_reflowed_child(widgetattrs,attrs.z or wcalc.z or 0)else
widget.realized=false
end
end
self:_determine_zorders()return maxw,maxh,expw,exph,expand_units,remaining_size,total_spacing
end
end)()

__mod_rtk_vbox=(function()
local rtk=__mod_rtk_core
rtk.VBox=rtk.class('rtk.VBox', rtk.Box)rtk.VBox.register{orientation=rtk.Box.VERTICAL
}function rtk.VBox:initialize(attrs,...)rtk.Box.initialize(self,attrs,self.class.attributes.defaults,...)end
function rtk.VBox:_reflow_step2(w,h,maxw,maxh,clampw,clamph,expand_units,remaining_size,total_spacing,uiscale,viewport,window,greedyw,greedyh,tp,rp,bp,lp)local expand_unit_size=expand_units>0 and((remaining_size-total_spacing)/expand_units)or 0
local offset=0
local spacing=0
local second_pass={}for n,widgetattrs in ipairs(self.children)do
local widget,attrs=table.unpack(widgetattrs)local wcalc=widget.calc
if widget==rtk.Box.FLEXSPACE then
if greedyh then
local previous=offset
offset=offset+expand_unit_size*(attrs.expand or 1)spacing=0
maxh=math.max(maxh,offset)self:_set_cell_box(attrs,lp,tp+previous,maxw,offset-previous)end
elseif widget.visible==true then
local wx,wy,ww,wh
local ctp,crp,cbp,clp=self:_get_cell_padding(widget,attrs)local need_second_pass=(attrs.stretch==rtk.Box.STRETCH_TO_SIBLINGS or
(attrs._halign and attrs._halign~=rtk.Widget.LEFT and
not(attrs.fillw and greedyw)and
attrs.stretch~=rtk.Box.STRETCH_FULL))local offx=lp+clp
local offy=offset+tp+ctp+spacing
local expand=attrs._calculated_expand
local cellh
if expand and greedyh and expand>0 then
local expanded_size=(expand_unit_size*expand)expand_units=expand_units-expand
if attrs._minh and attrs._minh>expanded_size then
local remaining_spacing=total_spacing-attrs._running_spacing_total
expand_unit_size=(remaining_size-attrs._minh-ctp-cbp-remaining_spacing)/expand_units
end
local child_maxw=rtk.clamp(w-clp-crp,attrs._minw,attrs._maxw)local child_maxh=rtk.clamp(expanded_size-ctp-cbp-spacing,attrs._minh,attrs._maxh)child_maxh=math.min(child_maxh,h-maxh-spacing)wx,wy,ww,wh=widget:reflow(0,0,child_maxw,child_maxh,attrs.fillw,attrs.fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)if attrs.stretch==rtk.Box.STRETCH_FULL and greedyw then
ww=maxw
end
wh=math.max(child_maxh,wh)cellh=ctp+wh+cbp
remaining_size=remaining_size-spacing-cellh
if need_second_pass then
second_pass[#second_pass+1]={widget,attrs,offx,offy,ww,child_maxh,ctp,crp,cbp,clp,offset,spacing
}else
self:_align_child(widget,attrs,offx,offy,ww,child_maxh,crp,cbp)self:_set_cell_box(attrs,lp,tp+offset+spacing,ww+clp+crp,cellh)end
else
ww=attrs.stretch==rtk.Box.STRETCH_FULL and greedyw and(maxw-clp-crp)or wcalc.w
wh=math.max(wcalc.h,attrs._minh or 0)cellh=ctp+wh+cbp
if need_second_pass then
second_pass[#second_pass+1]={widget,attrs,offx,offy,ww,wh,ctp,crp,cbp,clp,offset,spacing
}else
self:_align_child(widget,attrs,offx,offy,ww,wh,crp,cbp)self:_set_cell_box(attrs,lp,tp+offset+spacing,ww+clp+crp,cellh)end
end
if wcalc.position&rtk.Widget.POSITION_INFLOW~=0 then
offset=offset+spacing+cellh
end
maxw=math.max(maxw,ww+clp+crp)maxh=math.max(maxh,offset)spacing=(attrs.spacing or self.spacing)*uiscale
if not need_second_pass then
widget:_realize_geometry()end
end
end
if #second_pass>0 then
for n,widgetinfo in ipairs(second_pass)do
local widget,attrs,offx,offy,ww,child_maxh,ctp,crp,cbp,clp,offset,spacing=table.unpack(widgetinfo)if attrs.stretch==rtk.Box.STRETCH_TO_SIBLINGS then
widget:reflow(0,0,maxw,child_maxh,attrs.fillw,attrs.fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)end
self:_align_child(widget,attrs,offx,offy,maxw,child_maxh,crp,cbp)self:_set_cell_box(attrs,lp,tp+offset+spacing,maxw+clp+crp,child_maxh+ctp+cbp)widget:_realize_geometry()end
end
return maxw,maxh
end
function rtk.VBox:_align_child(widget,attrs,offx,offy,cellw,cellh,crp,cbp)local x,y=offx,offy
local wcalc=widget.calc
if cellh>wcalc.h then
if attrs._valign==rtk.Widget.BOTTOM then
y=(offy-cbp)+cellh-wcalc.h-cbp
elseif attrs._valign==rtk.Widget.CENTER then
y=offy+(cellh-wcalc.h)/2
end
end
if attrs._halign==rtk.Widget.CENTER then
x=(offx-crp)+(cellw-wcalc.w)/2
elseif attrs._halign==rtk.Widget.RIGHT then
x=offx+cellw-wcalc.w-crp
end
wcalc.x=wcalc.x+x
widget.box[1]=x
wcalc.y=wcalc.y+y
widget.box[2]=y
end
end)()

__mod_rtk_hbox=(function()
local rtk=__mod_rtk_core
rtk.HBox=rtk.class('rtk.HBox', rtk.Box)rtk.HBox.register{orientation=rtk.Box.HORIZONTAL
}function rtk.HBox:initialize(attrs,...)rtk.Box.initialize(self,attrs,self.class.attributes.defaults,...)end
function rtk.HBox:_reflow_step2(w,h,maxw,maxh,clampw,clamph,expand_units,remaining_size,total_spacing,uiscale,viewport,window,greedyw,greedyh,tp,rp,bp,lp)local expand_unit_size=expand_units>0 and((remaining_size-total_spacing)/expand_units)or 0
local offset=0
local spacing=0
local second_pass={}for n,widgetattrs in ipairs(self.children)do
local widget,attrs=table.unpack(widgetattrs)local wcalc=widget.calc
if widget==rtk.Box.FLEXSPACE then
if greedyw then
local previous=offset
offset=offset+expand_unit_size*(attrs.expand or 1)spacing=0
maxw=math.max(maxw,offset)self:_set_cell_box(attrs,lp+previous,tp,offset-previous,maxh)end
elseif widget.visible==true then
local wx,wy,ww,wh
local ctp,crp,cbp,clp=self:_get_cell_padding(widget,attrs)local need_second_pass=(attrs.stretch==rtk.Box.STRETCH_TO_SIBLINGS or
(attrs._valign and attrs._valign~=rtk.Widget.TOP and
not(attrs.fillh and greedyh)and
attrs.stretch~=rtk.Box.STRETCH_FULL))local offx=offset+lp+clp+spacing
local offy=tp+ctp
local expand=attrs._calculated_expand
local cellw
if expand and greedyw and expand>0 then
local expanded_size=(expand_unit_size*expand)expand_units=expand_units-expand
if attrs._minw and attrs._minw>expanded_size then
local remaining_spacing=total_spacing-attrs._running_spacing_total
expand_unit_size=(remaining_size-attrs._minw-clp-crp-remaining_spacing)/expand_units
end
local child_maxw=rtk.clamp(expanded_size-clp-crp,attrs._minw,attrs._maxw)child_maxw=math.min(child_maxw,w-maxw-spacing)local child_maxh=rtk.clamp(h-ctp-cbp,attrs._minh,attrs._maxh)wx,wy,ww,wh=widget:reflow(0,0,child_maxw,child_maxh,attrs.fillw,attrs.fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)if attrs.stretch==rtk.Box.STRETCH_FULL and greedyh then
wh=maxh
end
ww=math.max(child_maxw,ww)cellw=clp+ww+crp
remaining_size=remaining_size-spacing-cellw
if need_second_pass then
second_pass[#second_pass+1]={widget,attrs,offx,offy,child_maxw,wh,ctp,crp,cbp,clp,offset,spacing
}else
self:_align_child(widget,attrs,offx,offy,child_maxw,wh,crp,cbp)self:_set_cell_box(attrs,lp+offset+spacing,tp,cellw,wh+ctp+cbp)end
else
ww=math.max(wcalc.w,attrs._minw or 0)wh=attrs.stretch==rtk.Box.STRETCH_FULL and greedyh and(maxh-ctp-cbp)or wcalc.h
cellw=clp+ww+crp
if need_second_pass then
second_pass[#second_pass+1]={widget,attrs,offx,offy,ww,wh,ctp,crp,cbp,clp,offset,spacing
}else
self:_align_child(widget,attrs,offx,offy,ww,wh,crp,cbp)self:_set_cell_box(attrs,lp+offset+spacing,tp,cellw,wh+ctp+cbp)end
end
if wcalc.position&rtk.Widget.POSITION_INFLOW~=0 then
offset=offset+spacing+cellw
end
maxw=math.max(maxw,offset)maxh=math.max(maxh,wh+ctp+cbp)spacing=(attrs.spacing or self.spacing)*uiscale
if not need_second_pass then
widget:_realize_geometry()end
end
end
if #second_pass>0 then
for n,widgetinfo in ipairs(second_pass)do
local widget,attrs,offx,offy,child_maxw,wh,ctp,crp,cbp,clp,offset,spacing=table.unpack(widgetinfo)if attrs.stretch==rtk.Box.STRETCH_TO_SIBLINGS then
widget:reflow(0,0,child_maxw,maxh,attrs.fillw,attrs.fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)end
self:_align_child(widget,attrs,offx,offy,child_maxw,maxh,crp,cbp)self:_set_cell_box(attrs,lp+offset+spacing,tp,child_maxw+clp+crp,maxh+ctp+cbp)widget:_realize_geometry()end
end
return maxw,maxh
end
function rtk.HBox:_align_child(widget,attrs,offx,offy,cellw,cellh,crp,cbp)local x,y=offx,offy
local wcalc=widget.calc
if cellw>wcalc.w then
if attrs._halign==rtk.Widget.RIGHT then
x=(offx-crp)+cellw-wcalc.w-crp
elseif attrs._halign==rtk.Widget.CENTER then
x=offx+(cellw-wcalc.w)/2
end
end
if attrs._valign==rtk.Widget.CENTER then
y=(offy-cbp)+(cellh-wcalc.h)/2
elseif attrs._valign==rtk.Widget.BOTTOM then
y=offy+cellh-wcalc.h-cbp
end
wcalc.x=wcalc.x+x
widget.box[1]=x
wcalc.y=wcalc.y+y
widget.box[2]=y
end
end)()

__mod_rtk_flowbox=(function()
local rtk=__mod_rtk_core
rtk.FlowBox=rtk.class('rtk.FlowBox', rtk.Container)rtk.FlowBox.register{vspacing=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL,},hspacing=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL,},}function rtk.FlowBox:initialize(attrs,...)rtk.Container.initialize(self,attrs,self.class.attributes.defaults,...)end
function rtk.FlowBox:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
local x,y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)local inner_maxw=rtk.clamp(w or(boxw-lp-rp),minw,maxw)local inner_maxh=rtk.clamp(h or(boxh-tp-bp),minh,maxh)clampw=clampw or w~=nil or fillw
clamph=clamph or h~=nil or fillh
local child_geometry={}local hspacing=(calc.hspacing or 0)*rtk.scale.value
local vspacing=(calc.vspacing or 0)*rtk.scale.value
self._reflowed_children={}self._child_index_by_id={}local child_maxw=0
local child_totalh=0
for _,widgetattrs in ipairs(self.children)do
local widget,attrs=table.unpack(widgetattrs)local wcalc=widget.calc
if wcalc.visible==true and wcalc.position&rtk.Widget.POSITION_INFLOW~=0 then
local ctp,crp,cbp,clp=self:_get_cell_padding(widget,attrs)attrs._minw=self:_adjscale(attrs.minw,uiscale,greedyw and inner_maxw)attrs._maxw=self:_adjscale(attrs.maxw,uiscale,greedyw and inner_maxw)attrs._minh=self:_adjscale(attrs.minh,uiscale,greedyh and inner_maxh)attrs._maxh=self:_adjscale(attrs.maxh,uiscale,greedyh and inner_maxh)local wx,wy,ww,wh=widget:reflow(0,0,rtk.clamp(inner_maxw,attrs._minw,attrs._maxw),rtk.clamp(inner_maxh,attrs._minh,attrs._maxh),nil,nil,clampw,clamph,uiscale,viewport,window,false,false
)ww=ww+clp+crp
wh=wh+ctp+cbp
child_maxw=math.min(math.max(child_maxw,ww,attrs._minw or 0),inner_maxw)child_totalh=child_totalh+math.max(wh,attrs._minh or 0)child_geometry[#child_geometry+1]={x=wx,y=wy,w=ww,h=wh}end
end
child_totalh=child_totalh+(#self.children-1)*vspacing
local col_width=math.ceil(child_maxw)local num_columns=math.max(1,math.floor((inner_maxw+hspacing)/(col_width+hspacing)))local col_height=h
if not col_height and #child_geometry>0 then
col_height=child_geometry[1].h
for i=2,#child_geometry do
local need_columns=1
local cur_colh=0
for j=1,#child_geometry do
local wh=child_geometry[j].h
if cur_colh+wh>col_height then
need_columns=need_columns+1
cur_colh=0
end
cur_colh=cur_colh+wh+(j>1 and vspacing or 0)end
if need_columns<=num_columns then
num_columns=need_columns
break
end
col_height=col_height+vspacing+child_geometry[i].h
end
end
local col_width_max=math.floor((inner_maxw-((num_columns-1)*hspacing))/num_columns)local col={w=0,h=0,n=1}local offset={x=0,y=0}local inner={w=0,h=0}local chspacing=(col.n<num_columns)and hspacing or 0
for _,widgetattrs in ipairs(self.children)do
local widget,attrs=table.unpack(widgetattrs)local wcalc=widget.calc
attrs._cellbox=nil
if widget==rtk.Box.FLEXSPACE then
col.w=inner_maxw
elseif wcalc.visible==true then
local ctp,crp,cbp,clp=self:_get_cell_padding(widget,attrs)child_maxw=(attrs.fillw and attrs.fillw~=0)and col_width_max or col_width
local wx,wy,ww,wh=widget:reflow(clp,ctp,child_maxw-clp-crp,inner_maxh,attrs.fillw and attrs.fillw~=0,attrs.fillh and attrs.fillh~=0,clampw,clamph,uiscale,viewport,window,greedyw,greedyh
)wh=math.max(wh,attrs.minh or 0)if col.h+wh>col_height then
inner.w=inner.w+col.w
offset.x=offset.x+col.w
offset.y=0
col.w,col.h=0,0
col.n=col.n+1
chspacing=(col.n<num_columns)and hspacing or 0
end
wcalc.x=wx+offset.x+lp
wcalc.y=wy+offset.y+tp
widget.box[1]=widget.box[1]+offset.x+lp
widget.box[2]=widget.box[2]+offset.y+tp
self:_set_cell_box(attrs,lp+offset.x,tp+offset.y,child_maxw,wh+ctp+cbp)if wcalc.position&rtk.Widget.POSITION_INFLOW~=0 then
local cvspacing=(col.h+wh<col_height)and vspacing or 0
offset.y=offset.y+wy+wh+cvspacing
col.w=math.max(col.w,child_maxw+chspacing)col.h=col.h+wh+cvspacing+ctp+cbp
inner.h=math.max(inner.h,col.h)end
widget:_realize_geometry()self:_add_reflowed_child(widgetattrs,attrs.z or widget.z or 0)else
widget.realized=false
end
end
self:_determine_zorders()inner.w=inner.w+col.w
calc.x,calc.y=x,y
calc.w=math.ceil(rtk.clamp((w or inner.w)+lp+rp,minw,maxw))calc.h=math.ceil(rtk.clamp((h or inner.h)+tp+bp,minh,maxh))end
end)()

__mod_rtk_spacer=(function()
local rtk=__mod_rtk_core
rtk.Spacer=rtk.class('rtk.Spacer', rtk.Widget)function rtk.Spacer:initialize(attrs,...)rtk.Widget.initialize(self,attrs,rtk.Spacer.attributes.defaults,...)end
function rtk.Spacer:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
local y=calc.y+offy
if y+calc.h<0 or y>cliph or self.calc.ghost then
return false
end
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,alpha,event)self:_draw_borders(offx,offy,alpha)self:_handle_draw(offx,offy,alpha,event)end
end)()

__mod_rtk_button=(function()
local rtk=__mod_rtk_core
rtk.Button=rtk.class('rtk.Button', rtk.Widget)rtk.Button.static.RAISED=false
rtk.Button.static.FLAT=true
rtk.Button.static.LABEL=2
rtk.Button.register{[1]=rtk.Attribute{alias='label'},label=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},icon=rtk.Attribute{priority=true,reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)if type(value)=='string' then
local color=self.color
if self.calc.flat==rtk.Button.FLAT then
color=self.parent and self.parent.calc.bg or rtk.theme.bg
end
local style=rtk.color.get_icon_style(color,rtk.theme.bg)if self.icon and self.icon.style==style then
return self.icon
end
local img=rtk.Image.icon(value,style)if not img then
img=rtk.Image.make_placeholder_icon(24,24,style)end
return img
else
return value
end
end,},wrap=rtk.Attribute{default=false,reflow=rtk.Widget.REFLOW_FULL,},color=rtk.Attribute{default=function(self,attr)return rtk.theme.button
end,calculate=function(self,attr,value,target)local color=rtk.Widget.attributes.bg.calculate(self,attr,value,target)local luma=rtk.color.luma(color,rtk.theme.bg)local dark=luma<rtk.light_luma_threshold
local theme=rtk.theme
if dark~=theme.dark then
theme=dark and rtk.themes.dark or rtk.themes.light
end
self._theme=theme
if not self.textcolor then
target.textcolor={rtk.color.rgba(theme.button_label)}end
return color
end,},textcolor=rtk.Attribute{default=nil,calculate=rtk.Reference('bg'),},textcolor2=rtk.Attribute{default=function(self,attr)return rtk.theme.text
end,calculate=rtk.Reference('bg'),},iconpos=rtk.Attribute{default=rtk.Widget.LEFT,calculate=rtk.Reference('halign'),},tagged=false,flat=rtk.Attribute{default=rtk.Button.RAISED,calculate={raised=rtk.Button.RAISED,flat=rtk.Button.FLAT,label=rtk.Button.LABEL,[rtk.Attribute.NIL]=rtk.Button.RAISED,},},tagalpha=nil,surface=true,spacing=rtk.Attribute{default=10,reflow=rtk.Widget.REFLOW_FULL,},gradient=1,circular=rtk.Attribute{default=false,reflow=rtk.Widget.REFLOW_FULL,},elevation=rtk.Attribute{default=3,calculate=function(self,attr,value,target)return rtk.clamp(value,0,15)end
},hover=false,font=rtk.Attribute{default=function(self,attr)return self._theme_font[1]
end,reflow=rtk.Widget.REFLOW_FULL,},fontsize=rtk.Attribute{default=function(self,attr)return self._theme_font[2]
end,reflow=rtk.Widget.REFLOW_FULL,},fontscale=rtk.Attribute{default=1.0,reflow=rtk.Widget.REFLOW_FULL
},fontflags=rtk.Attribute{default=function(self,attr)return self._theme_font[3]
end
},valign=rtk.Widget.CENTER,tpadding=6,bpadding=6,lpadding=10,rpadding=10,autofocus=true,}function rtk.Button:initialize(attrs,...)self._theme=rtk.theme
self._theme_font=self._theme_font or rtk.theme.button_font or rtk.theme.default_font
rtk.Widget.initialize(self,attrs,self.class.attributes.defaults,...)self._font=rtk.Font()end
function rtk.Button:__tostring_info()return self.label or(self.icon and self.icon.path)end
function rtk.Button:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ret=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ret==false then
return ret
end
if self._segments and (attr == 'wrap' or attr == 'label') then
self._segments.dirty=true
end
if type(self.icon) == 'string' and (attr == 'color' or attr == 'label') then
self:attr('icon', self.icon, true)elseif attr=='icon' and value then
self._last_reflow_scale=nil
end
return ret
end
function rtk.Button:_reflow_get_max_label_size(boxw,boxh)local calc=self.calc
local seg=self._segments
if seg and seg.boxw==boxw and seg.wrap==calc.wrap and seg:isvalid()then
return self._segments,self.lw,self.lh
else
return self._font:layout(calc.label,boxw,boxh,calc.wrap)end
end
function rtk.Button:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)local icon=calc.icon
if icon and uiscale~=self._last_reflow_scale then
icon:refresh_scale()self._last_reflow_scale=uiscale
end
local scale=rtk.scale.value
local iscale=scale/(icon and icon.density or 1.0)local iw,ih
if calc.icon then
iw=math.round(icon.w*iscale)ih=math.round(icon.h*iscale)else
iw,ih=0,0
end
if calc.circular then
local size=math.max(iw,ih)if w and not h then
calc.w=w+lp+rp
elseif h and not w then
calc.w=h+tp+bp
else
calc.w=math.max(w or size,h or size)+lp+rp
end
calc.h=calc.w
self._radius=(calc.w-1)/2
if not self._shadow then
self._shadow=rtk.Shadow()end
self._shadow:set_circle(self._radius,calc.elevation)return
end
local spacing=0
local hpadding=lp+rp
local vpadding=tp+bp
if calc.label then
local lwmax=w or((clampw or(fillw and greedyw))and(boxw-hpadding)or math.inf)local lhmax=h or((clamph or(fillh and greedyh))and(boxh-vpadding)or math.inf)if icon then
spacing=calc.spacing*scale
if calc.tagged then
spacing=spacing+(calc.iconpos==rtk.Widget.LEFT and lp or rp)end
lwmax=lwmax-(iw+spacing)end
self._font:set(calc.font,calc.fontsize,calc.fontscale,calc.fontflags)self._segments,self.lw,self.lh=self:_reflow_get_max_label_size(lwmax,lhmax)self.lw=math.min(self.lw,lwmax)if icon then
calc.w=w or(iw+spacing+self.lw)calc.h=h or math.max(ih,self.lh)else
calc.w=w or self.lw
calc.h=h or self.lh
end
elseif icon then
calc.w=w or iw
calc.h=h or ih
else
calc.w=0
calc.h=0
end
calc.w=math.ceil(rtk.clamp(calc.w+hpadding,minw,maxw))calc.h=math.ceil(rtk.clamp(calc.h+vpadding,minh,maxh))end
function rtk.Button:_realize_geometry()if self.circular then
return
end
local calc=self.calc
local tp,rp,bp,lp=self:_get_padding_and_border()local surx,sury=0,0
local surw,surh=calc.surface and calc.w or 0,calc.h
local label=calc.label
local icon=calc.icon
local scale=rtk.scale.value
local iscale=scale/(icon and icon.density or 1.0)local spacing=calc.spacing*scale
local tagx,tagw=0,0
local lx=lp
local ix=lx
local lw,lh=self.lw,self.lh
if icon and label then
local iconwidth=icon.w*iscale
if calc.iconpos==rtk.Widget.LEFT then
if calc.tagged then
tagw=lp+iconwidth+lp
if calc.halign==rtk.Widget.LEFT then
lx=tagw+spacing
elseif calc.halign==rtk.Widget.CENTER then
lx=tagw+math.max(0,(calc.w-tagw-lw)/2)else
lx=math.max(tagw+spacing,calc.w-rp-lw)end
else
local sz=lw+spacing+iconwidth
if calc.halign==rtk.Widget.LEFT then
lx=lx+iconwidth+spacing
elseif calc.halign==rtk.Widget.CENTER then
local offset=math.max(0,(calc.w-sz)/2)ix=offset
lx=ix+iconwidth+spacing
else
lx=calc.w-rp-lw
ix=lx-spacing-iconwidth
if ix<0 then
lx=lp+iconwidth+spacing
ix=lp
end
end
end
else
if calc.tagged then
ix=calc.w-iconwidth-rp
tagx=ix-rp
tagw=rp+iconwidth+rp
if calc.halign==rtk.Widget.CENTER then
lx=math.max(0,(calc.w-tagw-lw)/2)elseif calc.halign==rtk.Widget.RIGHT then
lx=math.max(lp,calc.w-lw-tagw-spacing)end
else
local sz=lw+spacing+iconwidth
if calc.halign==rtk.Widget.LEFT then
ix=lx+lw+spacing
elseif calc.halign==rtk.Widget.CENTER then
local offset=math.max(0,(calc.w-sz)/2)lx=offset
ix=lx+spacing+lw
else
ix=calc.w-rp-iconwidth
lx=math.max(lx,ix-spacing-lw)end
end
end
else
local sz=icon and(icon.w*iscale)or lw
if calc.halign==rtk.Widget.CENTER then
local offset=(calc.w-sz)/2
lx=offset
elseif calc.halign==rtk.Widget.RIGHT then
lx=calc.w-rp-sz
end
ix=lx
end
local iy
if icon then
if calc.valign==rtk.Widget.TOP then
iy=sury+tp
elseif calc.valign==rtk.Widget.CENTER then
iy=sury+tp+math.max(0,calc.h-icon.h*iscale-tp-bp)/2
else
iy=sury+math.max(0,calc.h-icon.h*iscale-bp)end
end
local ly,clipw,cliph
if label then
if calc.valign==rtk.Widget.TOP then
ly=sury+tp
elseif calc.valign==rtk.Widget.CENTER then
ly=sury+tp+math.max(0,calc.h-lh-tp-bp)/2
else
ly=sury+math.max(0,calc.h-lh-bp)end
clipw=calc.w-lx
if calc.iconpos==rtk.Widget.RIGHT then
clipw=clipw-(tagw>0 and tagw or(calc.w-ix+calc.spacing))end
if rtk.os.mac and icon then
ly=ly+math.ceil(rtk.scale.value)end
cliph=calc.h-ly
end
self._pre={tp=tp,rp=rp,bp=bp,lp=lp,ix=ix,iy=iy,lx=lx,ly=ly,lw=lw,lh=lh,tagx=tagx,tagw=tagw,surx=surx,sury=sury,surw=surw or 0,surh=surh or 0,clipw=clipw,cliph=cliph,iw=icon and(icon.w*iscale),ih=icon and(icon.h*iscale),}end
function rtk.Button:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
if calc.disabled then
alpha=alpha*0.5
end
rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local x=calc.x+offx
local y=calc.y+offy
if y+calc.h<0 or y>cliph or calc.ghost then
return false
end
local hover=(self.hovering or calc.hover)and not calc.disabled
local clicked=hover and event.buttons~=0 and self:focused()and self.window.is_focused
local theme=self._theme
local gradient,brightness,cmul,bmul
if clicked then
gradient=theme.button_clicked_gradient*theme.button_gradient_mul
brightness=theme.button_clicked_brightness
cmul=theme.button_clicked_mul
bmul=theme.button_clicked_border_mul
elseif hover then
gradient=theme.button_hover_gradient*theme.button_gradient_mul
brightness=theme.button_hover_brightness
cmul=theme.button_hover_mul
bmul=theme.button_hover_border_mul
else
gradient=theme.button_normal_gradient*theme.button_gradient_mul
bmul=theme.button_normal_border_mul
brightness=1.0
cmul=1.0
end
self:_handle_drawpre(offx,offy,alpha,event)if self.circular then
self:_draw_circular_button(x,y,hover,clicked,gradient,brightness,cmul,bmul,alpha)else
self:_draw_rectangular_button(x,y,hover,clicked,gradient,brightness,cmul,bmul,alpha)self:_draw_borders(offx,offy,alpha)end
self:_handle_draw(offx,offy,alpha,event)end
function rtk.Button:_is_mouse_over(clparentx,clparenty,event)local calc=self.calc
if calc.circular then
local x=calc.x+clparentx+self._radius
local y=calc.y+clparenty+self._radius
return self.window and self.window.in_window and
rtk.point_in_circle(event.x,event.y,x,y,self._radius)else
return rtk.Widget._is_mouse_over(self,clparentx,clparenty,event)end
end
function rtk.Button:_draw_circular_button(x,y,hover,clicked,gradient,brightness,cmul,bmul,alpha)local calc=self.calc
local radius=math.ceil(self._radius)local cirx=math.floor(x)+radius
local ciry=math.floor(y)+radius
local icon=calc.icon
if calc.surface and(not calc.flat or hover or clicked)then
if calc.elevation>0 then
self._shadow:draw(x+1,y+1)end
local r,g,b,a=rtk.color.mod(calc.color,1.0,1.0,brightness)self:setcolor({r*cmul,g*cmul,b*cmul,a},alpha)gfx.circle(cirx,ciry,radius,1,1)end
if icon then
local ix=(calc.w-(icon.w*rtk.scale.value))/2
local iy=(calc.h-(icon.h*rtk.scale.value))/2
self:_draw_icon(x+ix,y+iy,hover,alpha)end
if calc.border then
local color,thickness=table.unpack(calc.border)self:setcolor(color)for i=1,thickness do
gfx.circle(cirx,ciry,radius-(i-1),0,1)end
end
end
function rtk.Button:_draw_rectangular_button(x,y,hover,clicked,gradient,brightness,cmul,bmul,alpha)local calc=self.calc
local pre=self._pre
local amul=calc.alpha*alpha
local label_over_surface=calc.surface and(calc.flat==rtk.Button.RAISED or hover)local textcolor=label_over_surface and calc.textcolor or calc.textcolor2
local draw_surface=label_over_surface or(calc.label and calc.tagged and calc.surface)local tagx=x+pre.tagx
local surx=x+pre.surx
local sury=y+pre.sury
local surw=pre.surw
local surh=pre.surh
if calc.tagged and calc.flat==rtk.Button.LABEL and calc.surface and not hover then
surx=tagx
surw=pre.tagw
end
if surw>0 and surh>0 and draw_surface then
local d=(gradient*calc.gradient)/calc.h
local lmul=1-calc.h*d/2
local r,g,b,a=rtk.color.rgba(calc.color)local sr,sg,sb,sa=rtk.color.mod({r,g,b,a},1.0,1.0,brightness*lmul,amul)gfx.gradrect(surx,sury,surw,surh,sr*cmul,sg*cmul,sb*cmul,sa*amul,0,0,0,0,r*d,g*d,b*d,0)gfx.set(r*bmul,g*bmul,b*bmul,amul)gfx.rect(surx,sury,surw,surh,0)if pre.tagw>0 and(hover or calc.flat~=rtk.Button.LABEL)then
local ta=1-(calc.tagalpha or self._theme.button_tag_alpha)self:setcolor({0,0,0,1})gfx.muladdrect(tagx,sury,pre.tagw,surh,ta,ta,ta,1.0)end
elseif calc.bg then
self:setcolor(calc.bg)gfx.rect(x,y,calc.w,calc.h,1)end
if calc.icon then
self:_draw_icon(x+pre.ix,y+pre.iy,hover,alpha)end
if calc.label then
self:setcolor(textcolor,alpha)self._font:draw(self._segments,x+pre.lx,y+pre.ly,pre.clipw,pre.cliph)end
end
function rtk.Button:_draw_icon(x,y,hovering,alpha)self.calc.icon:draw(x,y,self.calc.alpha*alpha,rtk.scale.value)end
end)()

__mod_rtk_entry=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Entry=rtk.class('rtk.Entry', rtk.Widget)rtk.Entry.static.contextmenu={{'Undo', id='undo'},rtk.NativeMenu.SEPARATOR,{'Cut', id='cut'},{'Copy', id='copy'},{'Paste', id='paste'},{'Delete', id='delete'},rtk.NativeMenu.SEPARATOR,{'Select All', id='select_all'},}rtk.Entry.register{[1]=rtk.Attribute{alias='value'},value=rtk.Attribute{default='',reflow=rtk.Widget.REFLOW_NONE,calculate=function(self,attr,value,target)return value and tostring(value) or ''end,},textwidth=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},icon=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)if type(value)=='string' then
local icon=self.calc.icon
local parentbg=self.parent and self.parent.calc.bg
local style=rtk.color.get_icon_style(self.calc.bg,parentbg or rtk.theme.bg)if icon and icon.style==style then
return icon
end
local img=rtk.Image.icon(value,style)if not img then
img=rtk.Image.make_placeholder_icon(24,24,style)end
return img
else
return value
end
end
},icon_alpha=0.6,spacing=rtk.Attribute{default=5,reflow=rtk.Widget.REFLOW_FULL
},placeholder=rtk.Attribute{default=nil,reflow=rtk.Widget.REFLOW_FULL,},textcolor=rtk.Attribute{default=function(self,attr)return rtk.theme.text
end,calculate=rtk.Reference('bg')},border_hover=rtk.Attribute{default=function(self,attr)return {rtk.theme.entry_border_hover,1}end,reflow=rtk.Widget.REFLOW_FULL,calculate=function(self,attr,value,target)return rtk.Widget.static._calc_border(self,value)end,},border_focused=rtk.Attribute{default=function(self,attr)return {rtk.theme.entry_border_focused,1}end,reflow=rtk.Widget.REFLOW_FULL,calculate=rtk.Reference('border_hover'),},blink=true,caret=rtk.Attribute{type='number',default=1,priority=true,reflow=rtk.Widget.REFLOW_NONE,calculate=function(self,attr,value,target)return rtk.clamp(value, 1, #(target.value or '') + 1)end,},font=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL,default=function(self,attr)return self._theme_font[1]
end
},fontsize=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL,default=function(self,attr)return self._theme_font[2]
end
},fontscale=rtk.Attribute{default=1.0,reflow=rtk.Widget.REFLOW_FULL
},fontflags=rtk.Attribute{default=function(self,attr)return self._theme_font[3]
end
},bg=rtk.Attribute{default=function(self,attr)return rtk.theme.entry_bg
end
},tpadding=4,rpadding=10,bpadding=4,lpadding=10,cursor=rtk.mouse.cursors.BEAM,autofocus=true,}function rtk.Entry:initialize(attrs,...)self._theme_font=rtk.theme.entry_font or rtk.theme.default_font
rtk.Widget.initialize(self,attrs,self.class.attributes.defaults,...)self._positions={0}self._backingstore=nil
self._font=rtk.Font()self._caretctr=0
self._selstart=nil
self._selend=nil
self._loffset=0
self._blinking=false
self._dirty_text=false
self._dirty_positions=nil
self._dirty_view=false
self._history=nil
self._last_doubleclick_time=0
self._num_doubleclicks=0
end
function rtk.Entry:_handle_attr(attr,value,oldval,trigger,reflow,sync)local calc=self.calc
local ok=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if attr=='value' then
self._dirty_text=true
if not self._dirty_positions then
local diff=math.min(#value,#oldval)for i=1,diff do
if value:sub(i,i)~=oldval:sub(i,i)then
diff=i
break
end
end
self._dirty_positions=diff
end
self._selstart=nil
local caret=rtk.clamp(calc.caret,1,#value+1)if caret~=calc.caret then
self:sync('caret', caret)end
if trigger then
self:_handle_change()end
elseif attr=='caret' then
self._dirty_view=true
elseif attr == 'bg' and type(self.icon) == 'string' then
self:attr('icon', self.icon, true)elseif attr=='icon' and value then
self._last_reflow_scale=nil
end
return true
end
function rtk.Entry:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
local lmaxw,lmaxh=nil,nil
if self._font:set(calc.font,calc.fontsize,calc.fontscale,calc.fontflags)then
self._dirty_positions=1
end
if calc.icon and uiscale~=self._last_reflow_scale then
calc.icon:refresh_scale()self._last_reflow_scale=uiscale
end
if calc.textwidth and not self.w then
local charwidth, _=gfx.measurestr('W')lmaxw,lmaxh=charwidth*calc.textwidth,self._font.texth
else
lmaxw, lmaxh=gfx.measurestr(calc.placeholder or "Dummy string!")end
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)calc.w=math.ceil(rtk.clamp((w or lmaxw)+lp+rp,minw,maxw))calc.h=math.ceil(rtk.clamp((h or lmaxh)+tp+bp,minh,maxh))self._ctp,self._crp,self._cbp,self._clp=tp,rp,bp,lp
if not self._backingstore then
self._backingstore=rtk.Image()end
self._backingstore:resize(calc.w,calc.h,false)self._dirty_text=true
end
function rtk.Entry:_unrealize()rtk.Widget._unrealize(self)self._backingstore=nil
end
function rtk.Entry:_calcpositions(startfrom)startfrom=startfrom or 1
local value=self.calc.value
self._font:set()for i=startfrom,#value+1 do
local w,_=gfx.measurestr(value:sub(1,i))self._positions[i+1]=w
end
self._dirty_positions=nil
end
function rtk.Entry:_calcview()local calc=self.calc
local curx=self._positions[calc.caret]
local curoffset=curx-self._loffset
local innerw=math.max(0,calc.w-(self._clp+self._crp))if calc.icon then
innerw=innerw-(calc.icon.w*rtk.scale.value/calc.icon.density)-calc.spacing
end
local loffset=self._loffset
if curoffset<0 then
loffset=curx
elseif curoffset>innerw then
loffset=curx-innerw
end
local last=self._positions[#calc.value+1]
if last>innerw then
local gap=innerw-(last-loffset)if gap>0 then
loffset=loffset-gap
end
else
loffset=0
end
if loffset~=self._loffset then
self._dirty_text=true
self._loffset=loffset
end
self._dirty_view=false
end
function rtk.Entry:_handle_focus(event,context)local ok=rtk.Widget._handle_focus(self,event,context)self._dirty_text=self._dirty_text or(ok and self._selstart)return ok
end
function rtk.Entry:_handle_blur(event,other)local ok=rtk.Widget._handle_blur(self,event,other)self._dirty_text=self._dirty_text or(ok and self._selstart)return ok
end
function rtk.Entry:_blink()if self.calc.blink and self:focused()then
self._blinking=true
local ctr=self._caretctr%16
self._caretctr=self._caretctr+1
if ctr==0 then
self:queue_draw()end
rtk.defer(self._blink,self)end
end
function rtk.Entry:_caret_from_mouse_event(event)local calc=self.calc
local iconw=calc.icon and(calc.icon.w*rtk.scale.value/calc.icon.density+calc.spacing)or 0
local relx=self._loffset+event.x-self.clientx-iconw-self._clp
for i=2,calc.value:len()+1 do
local pos=self._positions[i]
local width=pos-self._positions[i-1]
if relx<=self._positions[i]-width/2 then
return i-1
end
end
return calc.value:len()+1
end
local function is_word_break_character(value,pos)local c=value:sub(pos,pos)return c ~='_' and c:match('[%c%p%s]')end
function rtk.Entry:_get_word_left(spaces)local value=self.calc.value
local caret=self.calc.caret
if spaces then
while caret>1 and is_word_break_character(value,caret-1)do
caret=caret-1
end
end
while caret>1 and not is_word_break_character(value,caret-1)do
caret=caret-1
end
return caret
end
function rtk.Entry:_get_word_right(spaces)local value=self.calc.value
local caret=self.calc.caret
local len=value:len()while caret<=len and not is_word_break_character(value,caret)do
caret=caret+1
end
if spaces then
while caret<=len and is_word_break_character(value,caret)do
caret=caret+1
end
end
return caret
end
function rtk.Entry:select_all()self._selstart=1
self._selend=self.calc.value:len()+1
self._dirty_text=true
self:queue_draw()end
function rtk.Entry:select_range(a,b)local len=#self.calc.value
if len==0 or not a then
self._selstart=nil
else
b=b or a
self._selstart=math.max(1,a)self._selend=b>0 and math.min(len+1,b+1)or math.max(self._selstart,len+b+2)end
self._dirty_text=true
self:queue_draw()end
function rtk.Entry:get_selection_range()if self._selstart then
return math.min(self._selstart,self._selend),math.max(self._selstart,self._selend)end
end
function rtk.Entry:_edit(insert,delete_selection,dela,delb,caret)local calc=self.calc
local value=calc.value
if delete_selection then
dela,delb=self:get_selection_range()if dela and delb then
local ndeleted=delb-dela
caret=rtk.clamp(dela,1,#value)end
end
caret=caret or calc.caret
if dela and delb then
dela=rtk.clamp(dela,1,#value)delb=rtk.clamp(delb,1,#value+1)value=value:sub(1,dela-1)..value:sub(delb)self._dirty_positions=math.min(dela-1,self._dirty_positions or math.inf)end
if insert then
self._dirty_positions=math.min(caret-1,self._dirty_positions or math.inf)value=value:sub(0,caret-1)..insert..value:sub(caret)caret=caret+insert:len()end
if value~=calc.value then
caret=rtk.clamp(caret,1,#value+1)self:sync('value', value, nil, false)if caret~=calc.caret then
self:sync('caret', caret)end
self:_handle_change()self._dirty_view=true
end
end
function rtk.Entry:delete_range(a,b)self:push_undo()self:_edit(nil,nil,a,b)end
function rtk.Entry:delete()if self._selstart then
self:push_undo()end
self:_edit(nil,true)end
function rtk.Entry:clear()if self.calc.value ~='' then
self:push_undo()self:sync('value', '')end
end
function rtk.Entry:copy()if self._selstart then
local a,b=self:get_selection_range()local text=self.calc.value:sub(a,b-1)if rtk.clipboard.set(text)then
return text
end
end
end
function rtk.Entry:cut()local copied=self:copy()if copied then
self:delete()end
return copied
end
function rtk.Entry:paste()local str=rtk.clipboard.get()if str and str ~='' then
self:push_undo()self:_edit(str,true)return str
end
end
function rtk.Entry:insert(text)self:push_undo()self:_edit(text)end
function rtk.Entry:undo()local calc=self.calc
if self._history and #self._history>0 then
local state=table.remove(self._history,#self._history)local value,caret
value,caret,self._selstart,self._selend=table.unpack(state)self:sync('value', value)self:sync('caret', caret)return true
else
return false
end
end
function rtk.Entry:push_undo()if not self._history then
self._history={}end
local calc=self.calc
self._history[#self._history+1]={calc.value,calc.caret,self._selstart,self._selend}end
function rtk.Entry:_handle_mousedown(event)local ok=rtk.Widget._handle_mousedown(self,event)if ok==false then
return ok
end
if event.button==rtk.mouse.BUTTON_LEFT then
local caret=self:_caret_from_mouse_event(event)self._selstart=nil
self._dirty_text=true
self._caretctr=0
self:sync('caret', caret)self:queue_draw()elseif event.button==rtk.mouse.BUTTON_RIGHT then
if not self._popup then
self._popup=rtk.NativeMenu(rtk.Entry.contextmenu)end
local clipboard=rtk.clipboard.get()self._popup:item('undo').disabled = not self._history or #self._history == 0
self._popup:item('cut').disabled = not self._selstart
self._popup:item('copy').disabled = not self._selstart
self._popup:item('delete').disabled = not self._selstart
self._popup:item('paste').disabled = not clipboard or clipboard == ''self._popup:item('select_all').disabled = #self.calc.value == 0
self._popup:open_at_mouse():done(function(item)if item then
self[item.id](self)end
end)end
return true
end
function rtk.Entry:_handle_keypress(event)local ok=rtk.Widget._handle_keypress(self,event)if ok==false then
return ok
end
local calc=self.calc
local newcaret=nil
local len=calc.value:len()local orig_caret=calc.caret
local selecting=event.shift
if event.keycode==rtk.keycodes.LEFT then
if not selecting and self._selstart then
newcaret=self._selstart
elseif event.ctrl then
newcaret=self:_get_word_left(true)else
newcaret=math.max(1,calc.caret-1)end
elseif event.keycode==rtk.keycodes.RIGHT then
if not selecting and self._selstart then
newcaret=self._selend
elseif event.ctrl then
newcaret=self:_get_word_right(true)else
newcaret=math.min(calc.caret+1,len+1)end
elseif event.keycode==rtk.keycodes.HOME then
newcaret=1
elseif event.keycode==rtk.keycodes.END then
newcaret=calc.value:len()+1
elseif event.keycode==rtk.keycodes.DELETE then
if self._selstart then
self:delete()else
if event.ctrl then
self:push_undo()self:_edit(nil,false,calc.caret,self:_get_word_right(true)-1)elseif calc.caret<=len then
self:_edit(nil,false,calc.caret,calc.caret+1)end
end
elseif event.keycode==rtk.keycodes.BACKSPACE then
if calc.caret>=1 then
if self._selstart then
self:delete()else
if event.ctrl then
self:push_undo()local caret=self:_get_word_left(true)self:_edit(nil,false,caret,calc.caret,caret)elseif calc.caret>1 then
local caret=calc.caret-1
self:_edit(nil,false,caret,caret+1,caret)end
end
end
elseif event.char and not event.ctrl then
if self._selstart then
self:push_undo()end
self:_edit(event.char,true)selecting=false
elseif event.ctrl and event.char and not event.shift then
if event.char=='a' and len > 0 then
self:select_all()selecting=nil
elseif event.char=='c' then
self:copy()return true
elseif event.char=='x' then
self:cut()elseif event.char=='v' then
self:paste()elseif event.char=='z' then
self:undo()selecting=nil
end
else
return ok
end
if newcaret then
self:sync('caret', newcaret)end
if selecting then
if not self._selstart then
self._selstart=orig_caret
end
self._selend=calc.caret
self._dirty_text=true
elseif selecting==false and self._selstart then
self._selstart=nil
self._dirty_text=true
end
self._caretctr=0
log.debug2('keycode=%s char=%s caret=%s ctrl=%s shift=%s meta=%s alt=%s sel=%s-%s',event.keycode,event.char,calc.caret,event.ctrl,event.shift,event.meta,event.alt,self._selstart,self._selend
)return true
end
function rtk.Entry:_get_touch_activate_delay(event)if self:focused(event)then
return 0
else
return rtk.Widget._get_touch_activate_delay(self,event)end
end
function rtk.Entry:_handle_dragstart(event)if not self:focused(event)or event.button~=rtk.mouse.BUTTON_LEFT then
return
end
local draggable,droppable=self:ondragstart(self,event)if draggable==nil then
self._selstart=self.calc.caret
self._selend=self.calc.caret
return true,false
end
return draggable,droppable
end
function rtk.Entry:_handle_dragmousemove(event)local ok=rtk.Widget._handle_dragmousemove(self,event)if ok==false then
return ok
end
local selend=self:_caret_from_mouse_event(event)if selend==self._selend then
return ok
end
self._selend=selend
self:sync('caret', selend)self._dirty_text=true
return ok
end
function rtk.Entry:_handle_click(event)local ok=rtk.Widget._handle_click(self,event)if ok==false or event.button~=rtk.mouse.BUTTON_LEFT then
return ok
end
if event.time-self._last_doubleclick_time<0.7 then
local last=rtk.mouse.last[event.button]
local dx=last and math.abs(last.x-event.x)or 0
local dy=last and math.abs(last.y-event.y)or 0
if dx<3 and dy<3 then
self:select_all()end
self._last_doubleclick_time=0
elseif rtk.dnd.dragging~=self then
self:select_range(nil)rtk.Widget.focus(self)end
return ok
end
function rtk.Entry:_handle_doubleclick(event)local ok=rtk.Widget._handle_doubleclick(self,event)if ok==false or event.button~=rtk.mouse.BUTTON_LEFT then
return ok
end
self._last_doubleclick_time=event.time
local left=self:_get_word_left(false)local right=self:_get_word_right(true)self:sync('caret', right)self:select_range(left,right-1)return true
end
function rtk.Entry:_rendertext(x,y,event)self._font:set()self._backingstore:blit{src=gfx.dest,sx=x+self._clp,sy=y+self._ctp,mode=rtk.Image.FAST_BLIT
}self._backingstore:pushdest()if self._selstart and self:focused(event)then
local a,b=self:get_selection_range()self:setcolor(rtk.theme.entry_selection_bg)gfx.rect(self._positions[a]-self._loffset,0,self._positions[b]-self._positions[a],self._backingstore.h,1
)end
self:setcolor(self.calc.textcolor)self._font:draw(self.calc.value,-self._loffset,rtk.os.mac and 1 or 0)self._backingstore:popdest()self._dirty_text=false
end
function rtk.Entry:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
if offy~=self.offy or offx~=self.offx then
self._dirty_text=true
end
rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local x,y=calc.x+offx,calc.y+offy
local focused=self:focused(event)if(y+calc.h<0 or y>cliph or calc.ghost)and not focused then
return false
end
if self.disabled then
alpha=alpha*0.5
end
local scale=rtk.scale.value
local tp,rp,bp,lp=self._ctp,self._crp,self._cbp,self._clp
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,alpha,event)if not self._dirty_text then
gfx.x,gfx.y=x+lp,y+tp
local r,g,b=gfx.getpixel()if self._lastbg_r~=r or self._lastbg_g~=g or self._lastbg_b~=b then
self._lastbg_r,self._lastbg_g,self._lastbg_b=r,g,b
self._dirty_text=true
end
end
if self._dirty_positions then
self:_calcpositions(self._dirty_positions)end
if self._dirty_view or self._dirty_text then
self:_calcview()end
if self._dirty_text then
self:_rendertext(x,y,event)end
local amul=calc.alpha*alpha
local icon=calc.icon
if icon then
local a=math.min(1,calc.icon_alpha*alpha+(focused and 0.2 or 0))icon:draw(x+lp,y+((calc.h+tp-bp)-icon.h*scale/icon.density)/2,a*amul,scale
)lp=lp+icon.w*scale/icon.density+calc.spacing
end
self._backingstore:blit{sx=0,sy=0,sw=calc.w-lp-rp,sh=calc.h-tp-bp,dx=x+lp,dy=y+tp,alpha=amul,mode=rtk.Image.FAST_BLIT
}if calc.placeholder and #calc.value==0 then
self._font:set()self:setcolor(rtk.theme.entry_placeholder,alpha)self._font:draw(calc.placeholder,x+lp,y+tp+(rtk.os.mac and 1 or 0),calc.w-lp,calc.h-tp
)end
if focused then
local showcursor=not self._selstart or(self._selend-self._selstart)==0
if not self._blinking and showcursor then
self:_blink()end
self:_draw_borders(offx,offy,alpha,calc.border_focused)if self._caretctr%32<16 and showcursor then
local curx=x+self._positions[calc.caret]+lp-self._loffset
if curx>x and curx<=x+calc.w-rp then
self:setcolor(calc.textcolor,alpha)gfx.line(curx,y+tp,curx,y+calc.h-bp,0)end
end
else
self._blinking=false
if self.hovering then
self:_draw_borders(offx,offy,alpha,calc.border_hover)else
self:_draw_borders(offx,offy,alpha)end
end
self:_handle_draw(offx,offy,alpha,event)end
function rtk.Entry:onchange(event)end
function rtk.Entry:_handle_change(event)return self:onchange(event)end
end)()

__mod_rtk_text=(function()
local rtk=__mod_rtk_core
rtk.Text=rtk.class('rtk.Text', rtk.Widget)rtk.Text.static.WRAP_NONE=false
rtk.Text.static.WRAP_NORMAL=true
rtk.Text.static.WRAP_BREAK_WORD=2
rtk.Text.register{[1]=rtk.Attribute{alias='text'},text=rtk.Attribute{default='Text',reflow=rtk.Widget.REFLOW_FULL,},color=rtk.Attribute{reflow=rtk.Widget.REFLOW_NONE,default=rtk.Attribute.NIL,calculate=function(self,attr,value,target)if not value then
local parentbg=self.parent and self.parent.calc.bg
local luma=rtk.color.luma(self.calc.bg,parentbg or rtk.theme.bg)value=rtk.themes[luma > rtk.light_luma_threshold and 'light' or 'dark'].text
end
return {rtk.color.rgba(value)}end,},wrap=rtk.Attribute{default=rtk.Text.WRAP_NONE,reflow=rtk.Widget.REFLOW_FULL,calculate={['none']=rtk.Text.WRAP_NONE,['normal']=rtk.Text.WRAP_NORMAL,['break-word']=rtk.Text.WRAP_BREAK_WORD
},},textalign=rtk.Attribute{default=nil,calculate=rtk.Reference('halign'),},overflow=false,spacing=rtk.Attribute{default=0,reflow=rtk.Widget.REFLOW_FULL,},font=rtk.Attribute{default=function(self,attr)return self._theme_font[1]
end,reflow=rtk.Widget.REFLOW_FULL,},fontsize=rtk.Attribute{default=function(self,attr)return self._theme_font[2]
end,reflow=rtk.Widget.REFLOW_FULL,},fontscale=rtk.Attribute{default=1.0,reflow=rtk.Widget.REFLOW_FULL,},fontflags=rtk.Attribute{default=function(self,attr)return self._theme_font[3]
end
},}function rtk.Text:initialize(attrs,...)self._theme_font=self._theme_font or rtk.theme.text_font or rtk.theme.default_font
rtk.Widget.initialize(self,attrs,rtk.Text.attributes.defaults,...)self._font=rtk.Font()self._num_newlines=nil
end
function rtk.Text:__tostring_info()return self.text
end
function rtk.Text:_handle_attr(attr,value,oldval,trigger,reflow,sync)if attr == 'text' and reflow == rtk.Widget.REFLOW_DEFAULT and not self.calc.wrap then
if self.w or(self.box and self.box[5])then
local c=value:count('\n')if c==self._num_newlines then
reflow=rtk.Widget.REFLOW_PARTIAL
end
self._num_newlines=c
end
end
local ok=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if self._segments and (attr == 'text' or attr == 'wrap' or attr == 'textalign' or attr == 'spacing') then
self._segments.dirty=true
elseif attr=='bg' and not self.color then
self:attr('color', self.color, true, rtk.Widget.REFLOW_NONE)end
return ok
end
function rtk.Text:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)self._font:set(calc.font,calc.fontsize,calc.fontscale,calc.fontflags)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)local hpadding=lp+rp
local vpadding=tp+bp
local lmaxw=w or((clampw or(fillw and greedyw))and(boxw-hpadding)or math.inf)local lmaxh=h or((clamph or(fillh and greedyh))and(boxh-vpadding)or math.inf)local seg=self._segments
if not seg or seg.boxw~=lmaxw or not seg.isvalid()then
self._segments,self.lw,self.lh=self._font:layout(calc.text,lmaxw,lmaxh,calc.wrap~=rtk.Text.WRAP_NONE,self.textalign and calc.textalign or calc.halign,true,calc.spacing,calc.wrap==rtk.Text.WRAP_BREAK_WORD
)end
calc.w=(w and w+hpadding)or(fillw and greedyw and boxw)or math.min(clampw and boxw or math.inf,self.lw+hpadding)calc.h=(h and h+vpadding)or(fillh and greedyh and boxh)or math.min(clamph and boxh or math.inf,self.lh+vpadding)calc.w=math.ceil(rtk.clamp(calc.w,minw,maxw))calc.h=math.ceil(rtk.clamp(calc.h,minh,maxh))end
function rtk.Text:_realize_geometry()local calc=self.calc
local tp,rp,bp,lp=self:_get_padding_and_border()local lx,ly
if calc.halign==rtk.Widget.LEFT then
lx=lp
elseif calc.halign==rtk.Widget.CENTER then
lx=lp+math.max(0,calc.w-self.lw-lp-rp)/2
elseif calc.halign==rtk.Widget.RIGHT then
lx=math.max(0,calc.w-self.lw-rp)end
if calc.valign==rtk.Widget.TOP then
ly=tp
elseif calc.valign==rtk.Widget.CENTER then
ly=tp+math.max(0,calc.h-self.lh-tp-bp)/2
elseif calc.valign==rtk.Widget.BOTTOM then
ly=math.max(0,calc.h-self.lh-bp)end
self._pre={tp=tp,rp=rp,bp=bp,lp=lp,lx=lx,ly=ly,}end
function rtk.Text:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
local x,y=calc.x+offx,calc.y+offy
if y+calc.h<0 or y>cliph or calc.ghost then
return
end
local pre=self._pre
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,alpha,event)self:setcolor(calc.color,alpha)assert(self._segments)self._font:draw(self._segments,x+pre.lx,y+pre.ly,not calc.overflow and math.min(clipw-x,calc.w)-pre.lx-pre.rp or nil,not calc.overflow and math.min(cliph-y,calc.h)-pre.ly-pre.bp or nil
)self:_draw_borders(offx,offy,alpha)self:_handle_draw(offx,offy,alpha,event)end
end)()

__mod_rtk_heading=(function()
local rtk=__mod_rtk_core
rtk.Heading=rtk.class('rtk.Heading', rtk.Text)rtk.Heading.register{color=rtk.Attribute{default=function(self,attr)return rtk.theme.heading or rtk.theme.text
end
},}function rtk.Heading:initialize(attrs,...)self._theme_font=self._theme_font or rtk.theme.heading_font or rtk.theme.default_font
rtk.Text.initialize(self,attrs,self.class.attributes.defaults,...)end
end)()

__mod_rtk_imagebox=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.ImageBox=rtk.class('rtk.ImageBox', rtk.Widget)rtk.ImageBox.register{[1]=rtk.Attribute{alias='image'},image=rtk.Attribute{calculate=rtk.Entry.attributes.icon.calculate,reflow=rtk.Widget.REFLOW_FULL,},scale=rtk.Attribute{default=rtk.Attribute.NIL,reflow=rtk.Widget.REFLOW_FULL,},aspect=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL,},}function rtk.ImageBox:initialize(attrs,...)rtk.Widget.initialize(self,attrs,self.class.attributes.defaults,...)end
function rtk.ImageBox:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ret=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ret==false then
return ret
end
if attr=='image' and value then
self._last_reflow_scale=nil
elseif attr == 'bg' and type(self.image) == 'string' then
self:attr('image', self.image, true, rtk.Widget.REFLOW_NONE)end
return ret
end
function rtk.ImageBox:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,self.scale or 1,greedyw,greedyh
)local dstw,dsth=0,0
local hpadding=lp+rp
local vpadding=tp+bp
local image=calc.image
if image then
if uiscale~=self._last_reflow_scale then
image:refresh_scale()self._last_reflow_scale=uiscale
end
local scale=(self.scale or 1)*uiscale/image.density
local native_aspect=image.w/image.h
local aspect=calc.aspect or native_aspect
dstw=(w and w-hpadding)or((fillw and greedyw)and boxw-hpadding)dsth=(h and h-vpadding)or((fillh and greedyh)and boxh-vpadding)local constrain=self.scale==nil and not w and not h
if dstw and not dsth then
dsth=math.min(clamph and boxw or math.inf,dstw)/aspect
elseif not dstw and dsth then
dstw=math.min(clampw and boxh or math.inf,dsth)*aspect
elseif not dstw and not dsth then
dstw=image.w*scale/(native_aspect/aspect)dsth=image.h*scale
end
if constrain then
if dstw+hpadding>boxw then
dstw=boxw-hpadding
dsth=dstw/aspect
end
if dsth+vpadding>boxh then
dsth=boxh-vpadding
dstw=dsth*aspect
end
end
self.iscale=dstw/image.w
calc.aspect=aspect
calc.scale=self.iscale
else
self.iscale=1.0
end
self.iw=math.round(math.max(0,dstw))self.ih=math.round(math.max(0,dsth))calc.w=(fillw and greedyw and boxw)or math.min(clampw and boxw or math.inf,self.iw+hpadding)calc.h=(fillh and greedyh and boxh)or math.min(clamph and boxh or math.inf,self.ih+vpadding)calc.w=math.ceil(rtk.clamp(calc.w,minw,maxw))calc.h=math.ceil(rtk.clamp(calc.h,minh,maxh))end
function rtk.ImageBox:_realize_geometry()local calc=self.calc
local tp,rp,bp,lp=self:_get_padding_and_border()local ix,iy
if calc.halign==rtk.Widget.LEFT then
ix=lp
elseif calc.halign==rtk.Widget.CENTER then
ix=lp+math.max(0,calc.w-self.iw-lp-rp)/2
elseif calc.halign==rtk.Widget.RIGHT then
ix=math.max(0,calc.w-self.iw-rp)end
if calc.valign==rtk.Widget.TOP then
iy=tp
elseif calc.valign==rtk.Widget.CENTER then
iy=tp+math.max(0,calc.h-self.ih-tp-bp)/2
elseif calc.valign==rtk.Widget.BOTTOM then
iy=math.max(0,calc.h-self.ih-bp)end
self._pre={ix=ix,iy=iy}end
function rtk.ImageBox:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
local x,y=calc.x+offx,calc.y+offy
if y+calc.h<0 or y>cliph or calc.ghost then
return
end
local pre=self._pre
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,alpha,event)if calc.image then
calc.image:blit{dx=x+pre.ix,dy=y+pre.iy,dw=self.iw,dh=self.ih,alpha=calc.alpha*alpha,clipw=calc.w,cliph=calc.h,}end
self:_draw_borders(offx,offy,alpha)self:_handle_draw(offx,offy,alpha,event)end
end)()

__mod_rtk_optionmenu=(function()
local rtk=__mod_rtk_core
rtk.OptionMenu=rtk.class('rtk.OptionMenu', rtk.Button)rtk.OptionMenu.static._icon=nil
rtk.OptionMenu.register{[1]=rtk.Attribute{alias='menu'},menu=nil,icononly=rtk.Attribute{default=false,reflow=rtk.Widget.REFLOW_FULL,},selected=nil,selected_index=nil,selected_id=nil,selected_item=nil,icon=rtk.Attribute{default=function(self)return rtk.OptionMenu.static._icon
end,},iconpos=rtk.Widget.RIGHT,tagged=true,lpadding=10,rpadding=rtk.Attribute{default=function(self)return(self.icononly or self.circular)and self.lpadding or 7
end
},tagalpha=0.15,}function rtk.OptionMenu:initialize(attrs,...)if not rtk.OptionMenu._icon then
local icon=rtk.Image(13,17)icon:pushdest(icon.id)rtk.color.set(rtk.theme.text)gfx.triangle(2,6,10,6,6,10)icon:popdest()rtk.OptionMenu.static._icon=icon
end
rtk.Button.initialize(self,attrs,self.class.attributes.defaults,...)self._menu=rtk.NativeMenu()self:_handle_attr('menu', self.calc.menu)self:_handle_attr('icononly', self.calc.icononly)end
function rtk.OptionMenu:_reflow_get_max_label_size(boxw,boxh)local segments,lw,lh=rtk.Button._reflow_get_max_label_size(self,boxw,boxh)local w,h=0,0
for item in self._menu:items()do
local item_w,item_h=gfx.measurestr(item.altlabel or item.label)w=math.max(w,item_w)h=math.max(h,item_h)end
return segments,rtk.clamp(w,lw,boxw),rtk.clamp(h,lh,boxh)end
function rtk.OptionMenu:select(value,trigger)return self:attr('selected', value, trigger)end
function rtk.OptionMenu:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ok=rtk.Button._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if attr=='menu' then
self._menu:set(value)if not self.calc.icononly and not self.selected then
self:sync('label', '')elseif self.selected then
self:_handle_attr('selected', self.selected, self.selected, true)end
elseif attr=='selected' then
local item=self._menu:item(value)self.selected_item=item
if item then
if not self.calc.icononly  then
self:sync('label', item.altlabel or item.label)end
self.selected_index=item.index
self.selected_id=item.id
rtk.Button.onattr(self,attr,value,oldval,trigger)else
self.selected_index=nil
self.selected_id=nil
if not self.calc.icononly then
self:sync('label', '')end
end
local last=self._menu:item(oldval)if value~=oldval and trigger~=false then
self:onchange(item,last)self:onselect(item,last)elseif trigger then
self:onselect(item,last)end
end
return true
end
function rtk.OptionMenu:open()assert(self.menu, 'menu attribute was not set on OptionMenu')self._menu:open_at_widget(self):done(function(item)if item then
self:sync('selected', item.id or item.index, nil, true)end
end)end
function rtk.OptionMenu:_handle_mousedown(event)local ok=rtk.Button._handle_mousedown(self,event)if ok==false then
return ok
end
self:open()return true
end
function rtk.OptionMenu:onchange(item,lastitem)end
function rtk.OptionMenu:onselect(item,lastitem)end
end)()

__mod_rtk_checkbox=(function()
local rtk=__mod_rtk_core
rtk.CheckBox=rtk.class('rtk.CheckBox', rtk.Button)rtk.CheckBox.static._icon_unchecked=nil
rtk.CheckBox.static.DUALSTATE=0
rtk.CheckBox.static.TRISTATE=1
rtk.CheckBox.static.UNCHECKED=false
rtk.CheckBox.static.CHECKED=true
rtk.CheckBox.static.INDETERMINATE=2
function rtk.CheckBox.static._make_icons()local w,h=18,18
local wp,hp=2,2
local colors
if rtk.theme.dark then
colors={border={1,1,1,0.90},fill={1,1,1,1},check={0,0,0,1},checkaa={0.4,0.4,0.4,1},iborder={1,1,1,0.92},}else
colors={border={0,0,0,0.90},fill={0,0,0,1},check={1,1,1,1},checkaa={0.6,0.6,0.6,1},iborder={0,0,0,0.92},}end
local icon=rtk.Image(w,h)icon:pushdest()rtk.color.set(colors.border)rtk.gfx.roundrect(wp,hp,w-wp*2,h-hp*2,2,1)gfx.rect(wp+1,hp+1,w-wp*2-2,h-hp*2-2,0)icon:popdest()rtk.CheckBox.static._icon_unchecked=icon
icon=rtk.Image(w,h)icon:pushdest()rtk.color.set(colors.fill)rtk.gfx.roundrect(wp,hp,w-wp*2,h-hp*2,2,1)rtk.color.set(colors.fill)gfx.rect(wp+1,hp+1,w-wp*2-2,h-hp*2-2,1)rtk.color.set(colors.checkaa)gfx.x=wp+3
gfx.y=hp+6
gfx.lineto(wp+5,hp+9)gfx.lineto(wp+10,hp+3)rtk.color.set(colors.check)gfx.x=wp+2
gfx.y=hp+6
gfx.lineto(wp+5,hp+10)gfx.lineto(wp+11,hp+3)icon:popdest()rtk.CheckBox.static._icon_checked=icon
icon=rtk.CheckBox.static._icon_unchecked:clone()icon:pushdest()rtk.color.set(colors.iborder)gfx.rect(wp+3,hp+3,w-wp*2-6,h-hp*2-6)rtk.color.set(colors.fill)gfx.rect(wp+4,hp+4,w-wp*2-8,h-hp*2-8,1)icon:popdest()rtk.CheckBox.static._icon_intermediate=icon
rtk.CheckBox.static._icon_hover=rtk.CheckBox.static._icon_unchecked:clone():recolor(rtk.theme.accent)end
rtk.CheckBox.register{type=rtk.Attribute{default=rtk.CheckBox.DUALSTATE,calculate={dualstate=rtk.CheckBox.DUALSTATE,tristate=rtk.CheckBox.TRISTATE
},},label=nil,value=rtk.Attribute{default=rtk.CheckBox.UNCHECKED,calculate={[rtk.Attribute.NIL]=rtk.CheckBox.UNCHECKED,['true']=rtk.CheckBox.static.CHECKED,checked=rtk.CheckBox.static.CHECKED,['false']=rtk.CheckBox.static.UNCHECKED,unchecked=rtk.CheckBox.static.UNCHECKED,indeterminate=rtk.CheckBox.static.INDETERMINATE,}},icon=rtk.Attribute{default=function(self,attr)return self._value_map[rtk.CheckBox.UNCHECKED]
end,},surface=false,valign=rtk.Widget.TOP,wrap=true,tpadding=0,rpadding=0,lpadding=0,bpadding=0,}function rtk.CheckBox:initialize(attrs,...)if rtk.CheckBox.static._icon_unchecked==nil then
rtk.CheckBox._make_icons()end
self._value_map={[rtk.CheckBox.UNCHECKED]=rtk.CheckBox._icon_unchecked,[rtk.CheckBox.CHECKED]=rtk.CheckBox._icon_checked,[rtk.CheckBox.INDETERMINATE]=rtk.CheckBox._icon_intermediate
}rtk.Button.initialize(self,attrs,self.class.attributes.defaults,...)self:_handle_attr('value', self.calc.value)end
function rtk.CheckBox:_handle_click(event)local ret=rtk.Button._handle_click(self,event)if ret==false then
return ret
end
self:toggle()return ret
end
function rtk.CheckBox:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ret=rtk.Button._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ret~=false then
if attr=='value' then
self.calc.icon=self._value_map[value] or self._value_map[rtk.CheckBox.UNCHECKED]
if trigger then
self:onchange()end
end
end
return ret
end
function rtk.CheckBox:_draw_icon(x,y,hovering,alpha)rtk.Button._draw_icon(self,x,y,hovering,alpha)if hovering then
rtk.CheckBox._icon_hover:draw(x,y,alpha,rtk.scale.value)end
end
function rtk.CheckBox:toggle()local value=self.calc.value
if self.calc.type==rtk.CheckBox.DUALSTATE then
if value==rtk.CheckBox.CHECKED then
value=rtk.CheckBox.UNCHECKED
else
value=rtk.CheckBox.CHECKED
end
else
if value==rtk.CheckBox.CHECKED then
value=rtk.CheckBox.INDETERMINATE
elseif value==rtk.CheckBox.INDETERMINATE then
value=rtk.CheckBox.UNCHECKED
else
value=rtk.CheckBox.CHECKED
end
end
self:sync('value', value)return self
end
function rtk.CheckBox:onchange()end
end)()

__mod_rtk_application=(function()
local rtk=__mod_rtk_core
rtk.Application=rtk.class('rtk.Application', rtk.VBox)rtk.Application.register{status=rtk.Attribute{reflow=rtk.Widget.REFLOW_NONE
},statusbar=nil,toolbar=nil,screens=nil,}function rtk.Application:initialize(attrs,...)self.screens={stack={},}self.toolbar=rtk.HBox{bg=rtk.theme.bg,spacing=0,z=110,}self.toolbar:add(rtk.HBox.FLEXSPACE)self.statusbar=rtk.HBox{bg=rtk.theme.bg,lpadding=10,tpadding=5,bpadding=5,rpadding=10,z=110,}self.statusbar.text = self.statusbar:add(rtk.Text{color=rtk.theme.text_faded, text=""}, {fillw=true})rtk.VBox.initialize(self,attrs,self.class.attributes.defaults,...)self:add(self.toolbar,{minw=150,bpadding=2})self:add(rtk.VBox.FLEXSPACE)self._content_position=#self.children
self:add(self.statusbar,{fillw=true})self:_handle_attr('status', self.calc.status)end
function rtk.Application:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ok=rtk.VBox._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if attr=='status' then
self.statusbar.text:attr('text', value or ' ')end
return ok
end
function rtk.Application:add_screen(screen,name)assert(type(screen)=='table' and screen.init, 'screen must be a table containing an init() function')name=name or screen.name
assert(name, 'screen is missing name')assert(not self.screens[name], string.format('screen "%s" was already added', name))local widget=screen.init(self,screen)if widget then
assert(rtk.isa(widget, rtk.Widget), 'the return value from screen.init() must be type rtk.Widget (or nil)')screen.widget=widget
else
assert(rtk.isa(screen.widget, rtk.Widget), 'screen must contain a "widget" field of type rtk.Widget')end
screen.name=name
self.screens[name]=screen
if not screen.toolbar then
screen.toolbar=rtk.Spacer{h=0}end
self.toolbar:insert(1,screen.toolbar,{minw=50})screen.toolbar:hide()screen.widget:hide()if #self.screens.stack==0 then
self:replace_screen(screen)end
end
function rtk.Application:_show_screen(screen)screen=type(screen)=='table' and screen or self.screens[screen]
for _,s in ipairs(self.screens.stack)do
s.widget:hide()if s.toolbar then
s.toolbar:hide()end
end
assert(screen, 'screen not found, was add_screen() called?')if screen then
if screen.update then
screen.update(self,screen)end
if screen.widget.scrollto then
screen.widget:scrollto(0,0)end
screen.widget:show()self:replace(self._content_position,screen.widget,{expand=1,fillw=true,fillh=true,minw=screen.minw
})screen.toolbar:show()end
self:attr('status', nil)end
function rtk.Application:push_screen(screen)screen=type(screen)=='table' and screen or self.screens[screen]
assert(screen, 'screen not found, was add_screen() called?')if screen and #self.screens.stack>0 and self:current_screen()~=screen then
self:_show_screen(screen)self.screens.stack[#self.screens.stack+1]=screen
end
end
function rtk.Application:pop_screen()if #self.screens.stack>1 then
self:_show_screen(self.screens.stack[#self.screens.stack-1])table.remove(self.screens.stack)return true
else
return false
end
end
function rtk.Application:replace_screen(screen,idx)screen=type(screen)=='table' and screen or self.screens[screen]
assert(screen, 'screen not found, was add_screen() called?')local last=#self.screens.stack
idx=idx or last
if idx==0 then
idx=1
end
if idx>=last then
self:_show_screen(screen)elseif screen.update then
screen.update(self,screen)end
self.screens.stack[idx]=screen
end
function rtk.Application:current_screen()local n=#self.screens.stack
if n>0 then
return self.screens.stack[#self.screens.stack]
end
end
end)()

__mod_rtk_slider=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
rtk.Slider=rtk.class('rtk.Slider', rtk.Widget)rtk.Slider.static.TICKS_NEVER=0
rtk.Slider.static.TICKS_ALWAYS=1
rtk.Slider.static.TICKS_WHEN_ACTIVE=2
rtk.Slider.register{[1]=rtk.Attribute{alias='value'},value=rtk.Attribute{default=0,priority=true,reflow=rtk.Widget.REFLOW_NONE,calculate=function(self,attr,value,target)return type(value)=='table' and value or {value}end,set=function(self,attr,value,calculated,target)self._use_scalar_value=type(value) ~='table'for i=1,#calculated do
calculated[i]=rtk.clamp(tonumber(calculated[i]),target.min,target.max)if not self._thumbs[i] then
self._thumbs[i]={idx=i,radius=0,radius_target=0}end
end
for i=#calculated+1,#self._thumbs do
self._thumbs[i]=nil
end
target.value=calculated
end
},color=rtk.Attribute{type='color',default=function(self,attr)return rtk.theme.slider
end,calculate=rtk.Reference('bg'),},trackcolor=rtk.Attribute{type='color',default=function(self,attr)return rtk.theme.slider_track
end,calculate=rtk.Reference('bg'),},thumbsize=rtk.Attribute{default=6,reflow=rtk.Widget.REFLOW_FULL,},thumbcolor=rtk.Attribute{type='color',},ticklabels=rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL,},ticklabelcolor=rtk.Attribute {type='color',default=function(self,attr)return rtk.theme.slider_tick_label or rtk.theme.text
end,},spacing=rtk.Attribute{default=2,reflow=rtk.Widget.REFLOW_FULL,},ticks=rtk.Attribute{default=rtk.Slider.TICKS_NEVER,calculate={never=rtk.Slider.TICKS_NEVER,always=rtk.Slider.TICKS_ALWAYS,['when-active']=rtk.Slider.TICKS_WHEN_ACTIVE,['false']=rtk.Slider.TICKS_NEVER,[false]=rtk.Slider.TICKS_NEVER,['true']=rtk.Slider.TICKS_ALWAYS,[true]=rtk.Slider.TICKS_ALWAYS,},set=function(self,attr,value,calculated,target)self._tick_alpha=calculated==rtk.Slider.TICKS_ALWAYS and 1 or 0
target.ticks=calculated
end,},ticksize=rtk.Attribute{default=4,reflow=rtk.Widget.REFLOW_FULL,},tracksize=rtk.Attribute{default=2,reflow=rtk.Widget.REFLOW_FULL,},min=0,max=100,step=rtk.Attribute{type='number',calculate=function(self,attr,value,target)return value and value>0 and value
end,},font=rtk.Attribute{default=function(self,attr)return self._theme_font[1]
end,reflow=rtk.Widget.REFLOW_FULL,},fontsize=rtk.Attribute{default=function(self,attr)return self._theme_font[2]
end,reflow=rtk.Widget.REFLOW_FULL,},fontscale=rtk.Attribute{default=1.0,reflow=rtk.Widget.REFLOW_FULL
},fontflags=rtk.Attribute{default=function(self,attr)return self._theme_font[3]
end
},focused_thumb_index=1,autofocus=true,scroll_on_drag=false,}function rtk.Slider:initialize(attrs,...)self._thumbs={}self._tick_alpha=0
self._hovering_thumb=nil
self._font=rtk.Font()self._theme_font=rtk.theme.slider_font or rtk.theme.default_font
rtk.Widget.initialize(self,attrs,rtk.Slider.attributes.defaults,...)end
function rtk.Slider:_handle_attr(attr,value,oldval,trigger,reflow,sync)local ok=rtk.Widget._handle_attr(self,attr,value,oldval,trigger,reflow,sync)if ok==false then
return ok
end
if attr=='value' then
self:onchange()elseif self._label_segments and attr=='ticklabels' then
self._label_segments=nil
end
end
function rtk.Slider:_reflow(boxx,boxy,boxw,boxh,fillw,fillh,clampw,clamph,uiscale,viewport,window,greedyw,greedyh)local calc=self.calc
calc.x,calc.y=self:_get_box_pos(boxx,boxy)local w,h,tp,rp,bp,lp,minw,maxw,minh,maxh=self:_get_content_size(boxw,boxh,fillw,fillh,clampw,clamph,nil,greedyw,greedyh
)local hpadding=lp+rp
local vpadding=tp+bp
local lh=0
local segments=self._label_segments
self._font:set(calc.font,calc.fontsize,calc.fontscale,calc.fontflags)if calc.step and calc.ticklabels and(not segments or not segments[1].isvalid())then
local lmaxw=(clampw or(fillw and greedyw))and(boxw-hpadding)or w or math.inf
local lmaxh=(clamph or(fillh and greedyh))and(boxh-vpadding)or h or math.inf
segments={}for n=1,#calc.ticklabels do
local label=calc.ticklabels[n] or ''local s,w,h=self._font:layout(label,lmaxw,lmaxh,false,rtk.Widget.CENTER,true,0,false
)s.w=w
s.h=h
segments[#segments+1]=s
lh=math.max(h,lh)end
lh=lh+calc.spacing
self._label_segments=segments
end
self.lh=lh
minw=math.max(minw or 0,math.max(calc.minw or 0,#calc.value*calc.thumbsize*2)*rtk.scale.value)minh=math.max(minh or 0,math.max(calc.minh or 0,calc.thumbsize*2,calc.tracksize)*rtk.scale.value)local size=math.max(calc.thumbsize*2,calc.ticksize,calc.tracksize)*rtk.scale.value
calc.w=w and(w+hpadding)or(greedyw and boxw or 50)calc.h=h and(h+vpadding)or(size+self.lh+vpadding)calc.w=math.ceil(rtk.clamp(calc.w,minw,maxw))calc.h=math.ceil(rtk.clamp(calc.h,minh,maxh))return not w,false
end
function rtk.Slider:_realize_geometry()local calc=self.calc
local tp,rp,bp,lp=self:_get_padding_and_border()local scale=rtk.scale.value
local track={x=calc.x+lp+calc.thumbsize*scale,y=calc.y+tp+((calc.h-tp-bp-self.lh)-calc.tracksize*scale)/2,w=calc.w-lp-rp-calc.thumbsize*2*scale,h=calc.tracksize*scale,}local ticks
if calc.step then
ticks={distance=track.w/((calc.max-calc.min)/calc.step),size=calc.ticksize*scale,}ticks.offset=(ticks.size-track.h)/2
for x=track.x,track.x+track.w+1,ticks.distance do
ticks[#ticks+1]={x-ticks.offset,track.y-ticks.offset}end
if calc.ticklabels then
local ly=track.y+calc.tracksize+(calc.spacing+calc.thumbsize)*scale
for n,segments in ipairs(self._label_segments)do
local tick=ticks[n]
if not tick then
break
end
segments.x=tick[1]
local offset=segments.w-ticks.size
if n==#ticks then
segments.x=segments.x-offset
elseif n>1 then
segments.x=segments.x-offset/2
end
segments.y=ly
end
end
end
self._pre={tp=tp,rp=rp,bp=bp,lp=lp,track=track,ticks=ticks,}for idx=1,#self._thumbs do
self._thumbs[idx].value=nil
end
end
function rtk.Slider:_get_thumb(idx)assert(self._pre, '_get_thumb() called before reflow')local thumb=self._thumbs[idx]
local track=self._pre.track
local calc=self.calc
local value=calc.value[idx]
if thumb.value~=value then
thumb.pos=track.w*(value-calc.min)/(calc.max-calc.min)thumb.value=value
end
local c=self:calc('value')if c~=value then
thumb.pos_final=track.w*(c[idx]-calc.min)/(calc.max-calc.min)else
thumb.pos_final=thumb.pos
end
return thumb
end
function rtk.Slider:_get_nearest_thumb(clientx,clienty)local trackx=self.clientx+self._pre.lp
local tracky=self.clienty+self._pre.tp
local candidate=nil
local candidate_distance=nil
for i=1,#self._thumbs do
local thumb=self:_get_thumb(i)local delta=clientx-trackx-thumb.pos
local distance=math.abs(delta)if not candidate or(distance<candidate_distance)or(distance==candidate_distance and delta>0)then
candidate=thumb
candidate_distance=distance
end
end
return candidate
end
function rtk.Slider:_clamp_value_to_step(v)local calc=self.calc
local step=calc.step
return rtk.clamp(step and(math.round(v/step)*step)or v,calc.min,calc.max)end
function rtk.Slider:_set_thumb_value(thumbidx,value,animate,fast)value=self:_clamp_value_to_step(value)local current=self:calc('value')if current[thumbidx]==value then
return false
end
local newval=self._use_scalar_value and value or table.shallow_copy(current,{[thumbidx]=value})if animate==false then
self:cancel_animation('value')self:sync('value', newval)else
self:sync('value', newval, current)local duration=fast and 0.25 or 0.4
self:animate{'value', dst=newval, doneval=newval, duration=duration, easing='out-expo'}end
return true
end
function rtk.Slider:_set_thumb_value_with_crossover(idx,value,animate,event)local newidx
local calc=self.calc
if idx>1 and value<calc.value[idx-1] then
newidx=idx-1
elseif idx<#self._thumbs and value>calc.value[idx+1] then
newidx=idx+1
end
if newidx then
self:_set_thumb_value(idx,calc.value[newidx],false)self.focused_thumb_index=newidx
self._hovering_thumb=newidx
self:_animate_thumb_overlays(event,nil,true)end
local changed=self:_set_thumb_value(self.focused_thumb_index,value,animate,event.type~=rtk.Event.KEY)return changed,self.focused_thumb_index
end
function rtk.Slider:_is_mouse_over(clparentx,clparenty,event)if not self.window or not self.window.in_window then
self._hovering_thumb=nil
return false
end
local calc=self.calc
local pre=self._pre
local y=calc.y+clparenty+pre.tp
local track=pre.track
local trackx=track.x+clparentx
local tracky=track.y+clparenty
local radius=20*rtk.scale.value
if not event:is_widget_pressed(self)then
self._hovering_thumb=nil
if rtk.point_in_box(event.x,event.y,trackx-radius,y-radius,calc.w+radius*2,calc.h+radius*2)then
for i=1,#self._thumbs do
local thumb=self:_get_thumb(i)if rtk.point_in_circle(event.x,event.y,trackx+thumb.pos,tracky,radius)then
self._hovering_thumb=i
break
end
end
else
return false
end
end
return self._hovering_thumb or
rtk.point_in_box(event.x,event.y,trackx,y-calc.thumbsize,calc.w,calc.h+calc.thumbsize*2)end
function rtk.Slider:_handle_mouseleave(event)local ok=rtk.Widget._handle_mouseleave(self,event)if ok==false then
return ok
end
self:_animate_thumb_overlays(event)return ok
end
function rtk.Slider:_handle_mousedown(event)local ok=rtk.Widget._handle_mousedown(self,event)if ok==false then
return ok
end
local thumb=self:_get_nearest_thumb(event.x,event.y)self.focused_thumb_index=thumb.idx
if not self._hovering_thumb then
local value=self:_get_value_from_offset(event.x-self.clientx-self.calc.thumbsize)self:_set_thumb_value(thumb.idx,value,true,true)else
self._hovering_thumb=thumb.idx
end
self:_animate_thumb_overlays(event)self:_animate_ticks(true)return true
end
function rtk.Slider:_handle_mouseup(event)local ok=rtk.Widget._handle_mouseup(self,event)self:_animate_thumb_overlays(event,nil,true)self:_animate_ticks(false)return ok
end
function rtk.Slider:_handle_dragstart(event,x,y,t)local draggable,droppable=self:ondragstart(self,event,x,y,t)if draggable~=nil then
return draggable,droppable
end
local thumb=self:_get_nearest_thumb(x,y)self.focused_thumb_index=thumb.idx
self:_animate_thumb_overlays(event,nil,true)return {startx=x,starty=y,thumbidx=thumb.idx},false
end
function rtk.Slider:_handle_dragmousemove(event,arg)local ok=rtk.Widget._handle_dragmousemove(self,event)if ok==false or event.simulated then
return ok
end
if not arg.startpos then
local thumb=self:_get_thumb(arg.thumbidx)arg.startpos=thumb.pos_final
end
local offx=(event.x-arg.startx)if arg.fine then
offx=math.ceil(offx*0.2)end
local v=self:_get_value_from_offset(offx+arg.startpos)local value_changed
value_changed,arg.thumbidx=self:_set_thumb_value_with_crossover(arg.thumbidx,v,self.calc.step~=nil,event)if(event.shift and value_changed)or(event.shift~=arg.fine)then
arg.startx=event.x
arg.starty=event.y
arg.startpos=nil
end
arg.fine=event.shift
event:set_handled(self)return true
end
function rtk.Slider:_handle_dragend(event,dragarg)self:_animate_ticks(false)end
function rtk.Slider:_handle_mousemove(event)self:_animate_thumb_overlays(event)end
function rtk.Slider:_handle_focus(event,context)self:_animate_thumb_overlays(event,true)return rtk.Widget._handle_focus(self,event,context)end
function rtk.Slider:_handle_blur(event,other)self._hovering_thumb=nil
self:_animate_thumb_overlays(event,false)return rtk.Widget._handle_blur(self,event,other)end
function rtk.Slider:_handle_keypress(event)local ok=rtk.Widget._handle_keypress(self,event)if ok==false or not self.focused_thumb_index then
return ok
end
local calc=self.calc
local value=calc.value[self.focused_thumb_index]
local step=calc.step or(calc.max-calc.min)/10
if event.shift then
step=step*3
elseif event.ctrl then
step=step*2
end
local newvalue
if event.keycode==rtk.keycodes.LEFT or event.keycode==rtk.keycodes.DOWN then
newvalue=value-step
elseif event.keycode==rtk.keycodes.RIGHT or event.keycode==rtk.keycodes.UP then
newvalue=value+step
end
if newvalue then
self:_set_thumb_value_with_crossover(self.focused_thumb_index,newvalue,true,event)end
return ok
end
function rtk.Slider:_animate_thumb_overlays(event,focused,force)if rtk.dnd.dragging and not force then
return
end
if focused==nil then
focused=self.window.is_focused and self:focused(event)end
for i=1,#self._thumbs do
local dst=nil
local thumb=self:_get_thumb(i)if focused and thumb.idx==self.focused_thumb_index then
if event and event.buttons~=0 then
dst=32
else
dst=20
end
elseif thumb.idx==self._hovering_thumb then
dst=20
elseif thumb.radius_target>0 then
dst=0
end
if dst~=nil and dst~=thumb.radius_target then
thumb.radius_target=dst
rtk.queue_animation{key=string.format('%s.thumb.%d.hover', self.id, thumb.idx),src=thumb.radius,dst=dst,duration=0.2,easing='out-sine',update=function(val)thumb.radius=val
self:queue_draw()end,}end
end
end
function rtk.Slider:_animate_ticks(on)local calc=self.calc
if calc.step and calc.ticks==rtk.Slider.TICKS_WHEN_ACTIVE then
local dst=on and 1 or 0
rtk.queue_animation{key=string.format('%s.ticks', self.id),src=self._tick_alpha,dst=dst,duration=0.2,easing='out-sine',update=function(val)self._tick_alpha=val
self:queue_draw()end,}else
self._ticks_alpha=(calc.ticks==rtk.Slider.TICKS_ALWAYS)and 1 or 0
end
end
function rtk.Slider:_get_value_from_offset(offx)local calc=self.calc
local v=(offx*(calc.max-calc.min)/self._pre.track.w)+calc.min
return self:_clamp_value_to_step(v)end
function rtk.Slider:_draw(offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)rtk.Widget._draw(self,offx,offy,alpha,event,clipw,cliph,cltargetx,cltargety,parentx,parenty)local calc=self.calc
local y=calc.y+offy
if y+calc.h<0 or y>cliph or self.calc.ghost then
return false
end
local scale=rtk.scale.value
local pre=self._pre
local track=pre.track
local ticks=pre.ticks
local trackx=track.x+offx
local tracky=track.y+offy
local thumby=tracky+(track.h/2)local tickalpha=0.6*self._tick_alpha*alpha*calc.alpha
local drawticks=ticks and tickalpha>0 and not calc.disabled
self:_handle_drawpre(offx,offy,alpha,event)self:_draw_bg(offx,offy,alpha,event)self:setcolor(calc.trackcolor,alpha)gfx.rect(trackx,tracky,track.w,track.h,1)local first_thumb_x,last_thumb_x
if drawticks then
first_thumb_x=trackx+self:_get_thumb(1).pos
last_thumb_x=trackx+self:_get_thumb(#self._thumbs).pos
self:setcolor('black', tickalpha)for i=1,#ticks do
local x,y=table.unpack(ticks[i])if x<first_thumb_x or x>last_thumb_x then
gfx.rect(offx+x,offy+y,ticks.size,ticks.size,1)end
end
end
local thumbs={}local lastpos=0
for i=1,#self._thumbs do
local thumb=self:_get_thumb(i)local thumbx=trackx+thumb.pos
if not calc.disabled then
if #self._thumbs==1 or i>1 then
local segmentw=thumb.pos-lastpos
self:setcolor(calc.color,alpha)gfx.rect(trackx+lastpos,tracky,segmentw,track.h,1)if drawticks then
self:setcolor('white', tickalpha)for j=math.floor(lastpos/ticks.distance)+(i>1 and 2 or 1),#ticks do
local x,y=table.unpack(ticks[j])if x>=track.x+thumb.pos then
break
end
gfx.rect(offx+x,offy+y,ticks.size,ticks.size,1)end
end
end
if thumb.radius>0 then
self:setcolor(calc.thumbcolor or calc.color,0.25*alpha)gfx.circle(thumbx,thumby,thumb.radius*scale,1,1)end
end
thumbs[#thumbs+1]={thumbx,thumby}lastpos=thumb.pos
end
if not calc.disabled then
self:setcolor(calc.thumbcolor or calc.color,alpha)end
for i=1,#thumbs do
local pos=thumbs[i]
gfx.circle(pos[1],pos[2],calc.thumbsize*scale,1,1)end
if self._label_segments then
if not calc.disabled then
self:setcolor(calc.ticklabelcolor,alpha)end
for n,segments in ipairs(self._label_segments)do
if not segments.x then
break
end
self._font:draw(segments,offx+segments.x,offy+segments.y)end
end
self:_draw_borders(offx,offy,alpha)self:_handle_draw(offx,offy,alpha,event)end
function rtk.Slider:onchange()end
end)()

__mod_rtk_xml=(function()
local rtk=__mod_rtk_core
local log=__mod_rtk_log
local ATTR_PATTERNS={{'quoted', '^%s*([^>/%s=]+)%s*(=)%s*"([^"]+)"%s*(%/?)(%>?)'},{'quoted', "^%s*([^>/%s=]+)%s*(=)%s*'([^']+)'%s*(%/?)(%>?)"},{'mustache', '^%s*([^>/%s=]+)%s*(=)%s*({{)'},{'unquoted', '^%s*([^>/%s=]+)%s*(=)%s*([^%s/>]+)%s*(%/)(%>)'},{'unquoted', '^%s*([^>/%s=]+)%s*(=)%s*([^%s>]+)(%s*)(%>?)'},{'novalue', '^%s*([^>/%s]+)%s*()()(%/?)(%>?)'},}local ENTITIES={lt='<',gt='>',amp='&',apos="'",quot='"',nbsp=" ",}local function _unescape_entity(entity)local r=ENTITIES[entity]
if not r and entity:sub(1, 1)=='#' then
if entity:sub(2, 2)=='x' then
r=utf8.char(tonumber(entity:sub(3),16))else
r=utf8.char(tonumber(entity:sub(2)))end
end
return r
end
local function _unescape(s)return s and s:gsub('&([^;]+);', _unescape_entity)end
local function _gettag(s,pos,elem,userdata,ontagstart,onattr)local a, b, preamble, close, tag, selfclose, term=s:find('^([^%<]*)%<%s*(%/?)%s*([^>/%s]+)%s*(%/?)%s*(%>?)', pos)if not a then
return
end
pos=b+1
preamble=preamble:strip()if tag=='!--' then
local finish=s:find('%-%->', pos)if finish then
return finish+3,nil,false
else
return
end
elseif tag=='!DOCTYPE' then
local finish=s:find(']>', pos)if finish then
return finish+2,nil,false
else
log.warning('rtk.xml: invalid XML: DOCTYPE is not terminated')end
elseif tag:sub(1, 8)=='![CDATA[' then
local finish=s:find(']]>', pos)if finish then
if elem then
elem.content=tag:sub(9)..s:sub(pos,finish-1)else
log.warning('rtk.xml: invalid XML: CDATA occurs outside an element')end
return finish+3,nil,false
else
log.warning('rtk.xml: invalid XML: unterminated CDATA')if elem then
elem.content=tag:sub(9)..s:sub(pos)end
return
end
end
if close=='/' then
if not elem then
log.warning('rtk.xml: invalid XML: unexpected end tag "%s"', tag)return
elseif elem.tag~=tag then
log.warning('rtk.xml: mismatched end tag "%s" -- expected "%s"', tag, elem.tag)return
end
if preamble ~="" then
elem.content=(elem.content or '') .. _unescape(preamble)end
return pos, elem, close=='/' and 1
elseif preamble ~="" and elem then
elem.preamble=preamble
end
elem={tag=tag}if ontagstart and tag ~='?xml' then
ontagstart(elem,userdata)end
if term=='>' then
return pos,elem,false
end
local attrs={}elem.attrs=attrs
local attr,eq,value,whitespace
while true do
local pattern_type=nil
for p=1,#ATTR_PATTERNS do
local typ,pattern=table.unpack(ATTR_PATTERNS[p])a,b,attr,eq,value,selfclose,term=s:find(pattern,pos)if a then
pattern_type=typ
break
end
end
if not pattern_type or b+1<=pos then
break
end
if pattern_type=='mustache' then
local finish=s:find('}}', b+1)if not finish then
error(string.format('rtk.xml: terminating }} for expression not found for "%s"', attr), 3)end
value=s:sub(b+1,finish-1)b=finish+2
a, b, whitespace, selfclose, term=s:find('^(%s*)(%/?)(%>?)', b)if #selfclose==0 and #term==0 and #whitespace>0 then
error('rtk.xml: mustache expression has trailing characters -- perhaps quotes are needed?', 3)end
elseif pattern_type=='novalue' then
value=nil
else
value=_unescape(value)end
local attrtable={name=attr,value=value,type=pattern_type}if onattr and tag ~='?xml' then
onattr(elem,attrtable,userdata)end
assert(attrtable.name, 'attribute is missing name')attrs[attrtable.name]=attrtable
pos=b+1
if term=='>' then
break
end
end
return pos, elem, selfclose=='/' and 2
end
function rtk.xmlparse(args)local xml,userdata,ontagstart,ontagend,onattr
if type(args)=='string' then
xml=args
elseif type(args)=='table' then
xml=args.xml or args[1]
userdata=args.userdata or args[2]
ontagstart=args.ontagstart
ontagend=args.ontagend
onattr=args.onattr
else
error('rtk.xmlparse() must receive either a string or table')end
assert(type(xml)=='string', 'the XML document must be a string')local stack={}local root=nil
local pos=1
while true do
local last=stack[#stack]
local newpos,elem,closed=_gettag(xml,pos,last,userdata,ontagstart,onattr)if not newpos or newpos<=pos then
break
end
pos=newpos
if closed and ontagend then
ontagend(elem,userdata)end
if closed==1 then
table.remove(stack,#stack)elseif elem and elem.tag ~='?xml' then
if #stack>0 then
local current=stack[#stack]
current[#current+1]=elem
end
if not closed then
stack[#stack+1]=elem
end
end
if not root then
root=stack[#stack]
end
end
return root
end
end)()

rtk.log=__mod_rtk_log
local function init()rtk.script_path=({reaper.get_action_context()})[2]:match('^.+[\\//]')rtk._image_paths.fallback={rtk.script_path}rtk.reaper_hwnd=reaper.GetMainHwnd()local ver=reaper.GetAppVersion():lower()if ver:find('x64') or ver:find('arm64') or ver:find('_64') or ver:find('aarch64') then
rtk.os.bits=64
end
local parts=ver:gsub('/.*', ''):split('.')rtk._reaper_version_major=tonumber(parts[1])local minor=parts[2] or ''local sepidx=minor:find('%D')if sepidx then
rtk._reaper_version_prerelease=minor:sub(sepidx):gsub('^%+', '')minor=minor:sub(1,sepidx-1)end
minor=tonumber(minor)or 0
rtk._reaper_version_minor=minor<100 and minor or minor/10
rtk.version.parse()rtk.scale._discover()if rtk.os.mac then
rtk.font.multiplier=0.75
elseif rtk.os.linux then
rtk.font.multiplier=0.7
end
rtk.set_theme_by_bgcolor(rtk.color.get_reaper_theme_bg() or '#262626')rtk.theme.default=true
reaper.atexit(function()if rtk.window and rtk.window.running then
rtk.window:close()end
rtk.log.flush()end)end
init()return rtk
end)()
__mod_main=(function()
local t0=reaper.time_precise()local rtk=rtk
local t1=reaper.time_precise()__mod_app=(function()
__mod_lib_baseapp=(function()
local rtk=rtk
local log=rtk.log
__mod_lib_json=(function()
local json={ _version="0.1.2tack" }local encode
local escape_char_map={[ "\\" ] = "\\",[ "\"" ] = "\"",[ "\b" ] = "b",[ "\f" ] = "f",[ "\n" ] = "n",[ "\r" ] = "r",[ "\t" ] = "t",}local escape_char_map_inv = { [ "/" ] = "/" }for k,v in pairs(escape_char_map)do
escape_char_map_inv[v]=k
end
local function escape_char(c)return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))end
local function encode_nil(val)return "null"end
local function encode_table(val,stack)local res={}stack=stack or {}if stack[val] then error("circular reference") end
stack[val]=true
if rawget(val,1)~=nil or next(val)==nil then
local n=0
for k in pairs(val)do
if type(k) ~="number" then
error("invalid table: mixed or invalid key types")end
n=n+1
end
if n~=#val then
error("invalid table: sparse array")end
for i,v in ipairs(val)do
table.insert(res,encode(v,stack))end
stack[val]=nil
return "[" .. table.concat(res, ",") .. "]"else
for k,v in pairs(val)do
if type(k) ~="string" then
error("invalid table: mixed or invalid key types")end
table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))end
stack[val]=nil
return "{" .. table.concat(res, ",") .. "}"end
end
local function encode_string(val)return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'end
local function encode_number(val)if val~=val or val<=-math.huge or val>=math.huge then
error("unexpected number value '" .. tostring(val) .. "'")end
return tostring(val)end
local type_func_map={[ "nil"     ] = encode_nil,[ "table"   ] = encode_table,[ "string"  ] = encode_string,[ "number"  ] = encode_number,[ "boolean" ] = tostring,}encode=function(val,stack)local t=type(val)local f=type_func_map[t]
if f then
return f(val,stack)end
error("unexpected type '" .. t .. "'")end
function json.encode(val)return(encode(val))end
local parse
local function create_set(...)local res={}for i=1, select("#", ...) do
res[ select(i,...)]=true
end
return res
end
local space_chars=create_set(" ", "\t", "\r", "\n")local delim_chars=create_set(" ", "\t", "\r", "\n", "]", "}", ",")local escape_chars=create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")local literals=create_set("true", "false", "null")local literal_map={[ "true"  ] = true,[ "false" ] = false,[ "null"  ] = nil,}local function next_char(str,idx,set,negate)for i=idx,#str do
if set[str:sub(i,i)]~=negate then
return i
end
end
return #str+1
end
local function decode_error(str,idx,msg)local line_count=1
local col_count=1
for i=1,idx-1 do
col_count=col_count+1
if str:sub(i, i)=="\n" then
line_count=line_count+1
col_count=1
end
end
error( string.format("%s at line %d col %d", msg, line_count, col_count) )end
local function codepoint_to_utf8(n)local f=math.floor
if n<=0x7f then
return string.char(n)elseif n<=0x7ff then
return string.char(f(n/64)+192,n%64+128)elseif n<=0xffff then
return string.char(f(n/4096)+224,f(n%4096/64)+128,n%64+128)elseif n<=0x10ffff then
return string.char(f(n/262144)+240,f(n%262144/4096)+128,f(n%4096/64)+128,n%64+128)end
error( string.format("invalid unicode codepoint '%x'", n) )end
local function parse_unicode_escape(s)local n1=tonumber(s:sub(1,4),16)local n2=tonumber(s:sub(7,10),16)if n2 then
return codepoint_to_utf8((n1-0xd800)*0x400+(n2-0xdc00)+0x10000)else
return codepoint_to_utf8(n1)end
end
local function parse_string(str,i)local res={}local j=i+1
local k=j
while j<=#str do
local x=str:byte(j)if x<32 then
decode_error(str, j, "control character in string")elseif x==92 then
table.insert(res,str:sub(k,j-1))j=j+1
local c=str:sub(j,j)if c=="u" then
local hex=str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)or str:match("^%x%x%x%x", j + 1)or decode_error(str, j - 1, "invalid unicode escape in string")table.insert(res,parse_unicode_escape(hex))j=j+#hex
else
if not escape_chars[c] then
decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")end
table.insert(res,escape_char_map_inv[c])end
k=j+1
elseif x==34 then -- `"`: End of string
table.insert(res,str:sub(k,j-1))return table.concat(res),j+1
end
j=j+1
end
decode_error(str, i, "expected closing quote for string")end
local function parse_number(str,i)local x=next_char(str,i,delim_chars)local s=str:sub(i,x-1)local n=tonumber(s)if not n then
decode_error(str, i, "invalid number '" .. s .. "'")end
return n,x
end
local function parse_literal(str,i)local x=next_char(str,i,delim_chars)local word=str:sub(i,x-1)if not literals[word] then
decode_error(str, i, "invalid literal '" .. word .. "'")end
return literal_map[word],x
end
local function parse_array(str,i)local res={}local n=1
i=i+1
while 1 do
local x
i=next_char(str,i,space_chars,true)if str:sub(i, i)=="]" then
i=i+1
break
end
x,i=parse(str,i)res[n]=x
n=n+1
i=next_char(str,i,space_chars,true)local chr=str:sub(i,i)i=i+1
if chr=="]" then break end
if chr ~="," then decode_error(str, i, "expected ']' or ','") end
end
return res,i
end
local function parse_object(str,i)local res={}i=i+1
while 1 do
local key,val
i=next_char(str,i,space_chars,true)if str:sub(i, i)=="}" then
i=i+1
break
end
if str:sub(i, i) ~='"' then
decode_error(str, i, "expected string for key")end
key,i=parse(str,i)i=next_char(str,i,space_chars,true)if str:sub(i, i) ~=":" then
decode_error(str, i, "expected ':' after key")end
i=next_char(str,i+1,space_chars,true)val,i=parse(str,i)res[key]=val
i=next_char(str,i,space_chars,true)local chr=str:sub(i,i)i=i+1
if chr=="}" then break end
if chr ~="," then decode_error(str, i, "expected '}' or ','") end
end
return res,i
end
local char_func_map={[ '"' ] = parse_string,[ "0" ] = parse_number,[ "1" ] = parse_number,[ "2" ] = parse_number,[ "3" ] = parse_number,[ "4" ] = parse_number,[ "5" ] = parse_number,[ "6" ] = parse_number,[ "7" ] = parse_number,[ "8" ] = parse_number,[ "9" ] = parse_number,[ "-" ] = parse_number,[ "t" ] = parse_literal,[ "f" ] = parse_literal,[ "n" ] = parse_literal,[ "[" ] = parse_array,[ "{" ] = parse_object,}parse=function(str,idx)local chr=str:sub(idx,idx)local f=char_func_map[chr]
if f then
return f(str,idx)end
decode_error(str, idx, "unexpected character '" .. chr .. "'")end
function json.decode(str)if type(str) ~="string" then
error("expected argument of type string, got " .. type(str))end
local res,idx=parse(str,next_char(str,1,space_chars,true))idx=next_char(str,idx,space_chars,true)if idx<=#str then
decode_error(str, idx, "trailing garbage")end
return res
end
return json
end)()

local json=__mod_lib_json
local metadata=metadata
__mod_lib_utils=(function()
local rtk=rtk
local log=rtk.log
Path={sep=package.config:sub(1,1),resourcedir=reaper.GetResourcePath()}function Path.init(basedir)Path.basedir=basedir
end
Path.join=function(first,...)local args={...}local joined=first
local prev=first
for _,part in ipairs(args)do
if prev:sub(-1)~=Path.sep then
joined=joined..Path.sep..part
else
joined=joined..part
end
prev=part
end
return joined
end
local notes={'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}function note_to_name(note)local offset=2 - reaper.SNM_GetIntConfigVar("midioctoffs", 0)return string.format('%s%d', notes[(note % 12) + 1], math.floor(note / 12) - offset)end
function as_filtered_table(...)local args=table.pack(...)local new={}for i=1,args.n do
local v=args[i]
if v~=nil then
new[#new+1]=v
end
end
return new
end
function remap_bank_select_multiple(track,msblsbmap)log.info('utils: remap bank selects: %s', table.tostring(msblsbmap))local lastmsb={}local n_remapped=0
for itemidx=0,reaper.CountTrackMediaItems(track)-1 do
local item=reaper.GetTrackMediaItem(track,itemidx)for takeidx=0,reaper.CountTakes(item)-1 do
local dosort=false
local take=reaper.GetTake(item,takeidx)local _,_,numccs,_=reaper.MIDI_CountEvts(take)for ccidx=0,numccs-1 do
local r,selected,muted,evtppq,command,evtchan,msg2,msg3=reaper.MIDI_GetCC(take,ccidx)if command==0xb0 then
if msg2==0 then
local lsbmap=msblsbmap[msg3] or msblsbmap[-1]
if lsbmap then
lastmsb[evtchan]={msg3,ccidx,lsbmap}end
elseif msg2==32 and lastmsb[evtchan] then
local srcmsb,srcidx,lsbmap=table.unpack(lastmsb[evtchan])local targetmap=lsbmap[msg3] or lsbmap[-1]
if targetmap then
local dstmsb,dstlsb,bank=table.unpack(targetmap)if dstmsb and(srcmsb~=dstmsb or msg3~=dstlsb)then
reaper.MIDI_SetCC(take,srcidx,nil,nil,nil,nil,nil,nil,dstmsb,true)reaper.MIDI_SetCC(take,ccidx,nil,nil,nil,nil,nil,nil,dstlsb,true)n_remapped=n_remapped+1
dosort=true
end
end
lastmsb[evtchan]=nil
end
end
end
if dosort then
reaper.MIDI_Sort(take)end
end
end
return n_remapped
end
function remap_bank_select(track,frombank,tobank)if not reaper.ValidatePtr2(0, track, "MediaTrack*") then
return 0
end
if not tobank then
log.warning('remap_bank_select: target bank is nil')return 0
end
local tomsb,tolsb,frommsb,fromlsb
if #tobank==2 then
tomsb,tolsb=table.unpack(tobank)else
tomsb,tolsb=tobank:get_current_msb_lsb()end
if not tomsb then
log.warning('remap_bank_select: target bank %s has no MSB/LSB mapping in project', tobank.name)return 0
end
if frombank then
if #frombank==2 then
frommsb,fromlsb=table.unpack(frombank)else
frommsb,fromlsb=frombank:get_current_msb_lsb()end
if not frommsb then
log.warning('remap_bank_select: source bank %s has no MSB/LSB mapping in project', frombank.name)return 0
end
else
frommsb=-1
fromlsb=-1
end
reaper.Undo_BeginBlock2(0)local n=remap_bank_select_multiple(track,{[frommsb]={[fromlsb]={tomsb,tolsb,tobank}}})reaper.Undo_EndBlock2(0, 'Reaticulate: update Bank Select events', UNDO_STATE_ITEMS)return n
end
function call_and_preserve_selected_tracks(func,...)local selected={}for i=0,reaper.CountSelectedTracks(0)-1 do
local track=reaper.GetSelectedTrack(0,i)local n=reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')selected[n]=true
end
local modified=false
reaper.PreventUIRefresh(1)local r=func(...)for i=0,reaper.CountTracks(0)-1 do
local track=reaper.GetTrack(0,i)local n=reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')if reaper.IsTrackSelected(track)~=(selected[n] or false)then
if not modified then
reaper.Undo_BeginBlock2(0)modified=true
end
reaper.SetTrackSelected(track,selected[n] or false)end
end
if modified then
reaper.Undo_EndBlock2(0, 'Reaticulate: update track selection', UNDO_STATE_FREEZE)end
reaper.PreventUIRefresh(-1)return r
end
end)()

local BaseApp=rtk.class('BaseApp', rtk.Application)app=nil
function BaseApp:initialize(appid,title,basedir)if not rtk.has_sws_extension then
reaper.MB("Reaticulate requires the SWS extensions (www.sws-extension.org).\n\nAborting!","SWS extension missing", 0)return false
end
if not rtk.check_reaper_version(5,975)then
reaper.MB('Sorry, Reaticulate requires REAPER v5.975 or later.', 'REAPER version too old', 0)return false
end
app=self
Path.init(basedir)Path.imagedir=Path.join(Path.basedir, 'img')self.cmdserial=0
self.cmdcallbacks={}self.cmdpending=0
self.appid=appid
if not self.config then
self.config={}end
table.merge(self.config,{x=0,y=0,w=640,h=480,dockstate=nil,dock=nil,docked=nil,scale=1.0,bg=nil,borderless=false,touchscroll=false,smoothscroll=true,})self.config=self:get_config()rtk.scale.user=self.config.scale
if metadata._VERSION:find('pre') then
if not self.config.showed_prerelease_warning then
local response=reaper.MB('WARNING! You are using a pre-release version of Reaticulate.\n\n' ..'Projects saved with this version of Reaticulate WILL NOT WORK if you downgrade to the stable ' ..'release, and you will only be able to move forward to later versions of Reaticulate. Please only ' ..'use pre-releases if you can tolerate and are willing to report bugs. Be sure to backup your ' ..'projects before re-saving.\n\n' ..'Continue using this pre-release version?\n\n' ..'If you answer OK, Reaticulate will continue on and this warning will not be displayed again.\n\n' ..'If you Cancel, Reaticulate will abort and you can downgrade to a stable version via ReaPack.','UNSTABLE Reaticulate pre-release version in use',1)if response==2 then
return false
end
self.config.showed_prerelease_warning=true
end
else
self.config.showed_prerelease_warning=false
end
if self.config.debug_level==true or self.config.debug_level==1 then
self.config.debug_level=log.DEBUG
self:save_config()elseif self.config.debug_level==false or self.config.debug_level==0 then
self.config.debug_level=log.ERROR
self:save_config()end
rtk.touchscroll=app.config.touchscroll
rtk.smoothscroll=app.config.smoothscroll
self:set_theme()rtk.Application.initialize(self)self.window=rtk.Window{title=title,x=self.config.x,y=self.config.y,w=rtk.clamp(self.config.w,0,4096),h=rtk.clamp(self.config.h,0,4096),dock=self.config.dock or 'right',docked=self.config.docked,borderless=self.config.borderless,pinned=self.config.pinned,ondock=function()self:handle_ondock()end,onattr=function(_,attr,value)self:handle_onattr(attr,value)end,onmove=function()self:handle_onmove()end,onresize=function()self:handle_onresize()end,onupdate=function()self:handle_onupdate()end,onmousewheel=function(_,event)self:handle_onmousewheel(event)end,onclose=function()self:handle_onclose()end,onkeypresspost=function(_,event)self:handle_onkeypresspost(event)end,ondropfile=function(_,event)self:handle_ondropfiles(event)end,onclick=function(_,event)self:handle_onclick(event)end,}self:build_frame()end
function BaseApp:run()self:handle_onupdate()rtk.window:open{constrain=true}end
function BaseApp:add_screen(name,package)local screen=load("return __mod_" .. package:gsub("%.", "_"))()rtk.Application.add_screen(self,screen,name)end
local function _swallow_event(self,event)event:set_handled(self)return false
end
function BaseApp:make_button(icon,label,textured,attrs)local defaults={icon=icon,label=label,flat=true,touch_activate_delay=0
}attrs=table.merge(defaults,attrs or {})local button=rtk.Button(attrs)button.ondragstart=_swallow_event
return button
end
function BaseApp:get_icon_path(name)end
function BaseApp:fatal_error(msg)msg=msg..'\n\nThis is an unrecoverable error and Reaticulate must now exit. ' ..'\n\nPlease visit https://reaticulate.com/ for support contact details.'reaper.ShowMessageBox(msg, "Reaticulate fatal error", 0)rtk.quit()end
function BaseApp:get_ext_state(key)if not reaper.HasExtState(self.appid,key)then
return
end
local encoded=reaper.GetExtState(self.appid,key)local ok,decoded=pcall(json.decode,encoded)return ok and decoded,encoded
end
function BaseApp:set_ext_state(key,obj,persist)local serialized=json.encode(obj)reaper.SetExtState(self.appid,key,serialized,persist or false)log.debug('baseapp: wrote ext state "%s" (size=%s persist=%s)', key, #serialized, persist)return serialized
end
function BaseApp:get_config(appid,target)local config, encoded=self:get_ext_state('config')if not config and encoded then
local ok
log.info('baseapp: config failed to parse as JSON: %s', encoded)ok,config=pcall(table.fromstring,encoded)if not ok then
reaper.MB("Reaticulate wasn't able to parse its saved configuration. This may be because " .."you downgraded Reaticulate and it doesn't understand the format used by a future " .."version.\n\nAll Reaticulate settings will need to be reset to defaults.",'Unrecognized Reaticulate configuration',0
)config=nil
else
self:save_config(config)end
end
if config then
table.merge(self.config,config)end
self:set_debug(self.config.debug_level or log.ERROR)if not self.config.dock and self.config.dockstate then
self.config.dock=(self.config.dockstate>>8)&0xff
self.config.docked=(self.config.dockstate&0x01)~=0
end
return self.config
end
function BaseApp:save_config(config)self:_do_save_config(config,true)end
function BaseApp:queue_save_config(config)if not self._save_config_queued then
rtk.callafter(0.25,self._do_save_config,self,config)self._save_config_queued=true
end
end
function BaseApp:_do_save_config(config,force)if not self._save_config_queued and not force then
return
end
local cfg=self:set_ext_state('config', config or self.config, true)self._save_config_queued=false
end
function BaseApp:set_debug(level)self.config.debug_level=level
self:save_config()log.level=level or log.ERROR
log.info("baseapp: Reaticulate log level is %s", log.level_name())end
function BaseApp:zoom(increment)if increment==0 then
rtk.scale.user=1.0
else
rtk.scale.user=rtk.clamp(rtk.scale.user+increment,0.5,4.0)end
log.info('zoom %.02f', rtk.scale.user)self:set_statusbar(string.format('Zoom UI to %.02fx', rtk.scale.user))self.config.scale=rtk.scale.user
self:save_config()end
function BaseApp:handle_onattr(attr,value)if attr == 'pinned' or attr == 'docked' or attr == 'dock' then
self:handle_ondock()end
end
function BaseApp:handle_ondock()self.config.pinned=self.window.pinned
self.config.docked=self.window.docked
self.config.dock=self.window.dock
if rtk.has_js_reascript_api then
if self.window.docked then
self.toolbar.pin:hide()self.toolbar.unpin:hide()else
self:_set_window_pinned(self.config.pinned)end
end
self:save_config()end
function BaseApp:handle_onresize()if not self.window.docked then
self.config.w=self.window.w
self.config.h=self.window.h
self:queue_save_config()end
end
function BaseApp:handle_onmove()if not self.window.docked then
self.config.x=self.window.x
self.config.y=self.window.y
self:queue_save_config()end
end
function BaseApp:handle_onmousewheel(event)if event.ctrl and not rtk.is_modal()then
self:zoom(event.wheel<0 and 0.10 or-0.10)event:set_handled()end
end
function BaseApp:set_theme()local bg=self.config.bg
if not bg or type(bg) ~= 'string' or #bg <= 1 then
bg=rtk.color.get_reaper_theme_bg()end
rtk.set_theme_by_bgcolor(bg)rtk.add_image_search_path(Path.imagedir)local icons={medium={'add_circle_outline','arrow_back','auto_fix','delete','dock_window','drag_vertical','edit','eraser','info_outline','link','pin_off','pin_on','search','settings','sync','undo','undock_window','view_list',},large={'alert_circle_outline','drag_vertical','info_outline','plus','warning_amber',},huge={'alert_circle_outline',},}local img=rtk.ImagePack():add{src='icons.png', style='light',{w=18, size='medium', names=icons.medium, density=1},{w=24, size='large', names=icons.large, density=1},{w=96, size='huge', names=icons.huge, density=1},{w=28, size='medium', names=icons.medium, density=1.5},{w=36, size='large', names=icons.large, density=1.5},{w=144, size='huge', names=icons.huge, density=1.5},{w=36, size='medium', names=icons.medium, density=2},{w=48, size='large', names=icons.large, density=2},{w=192, size='huge', names=icons.huge, density=2},}img:register_as_icons()end
function BaseApp:set_statusbar(label)self:attr('status', label)end
function BaseApp:build_frame()self.window:add(self)if rtk.has_js_reascript_api then
local pin = rtk.Button{icon='pin_off', flat=true, tooltip='Pin window to top'}local unpin = rtk.Button{icon='pin_on', flat=true, tooltip='Unpin window from top'}self.toolbar.pin=self.toolbar:add(pin,{rpadding=15})self.toolbar.unpin=self.toolbar:add(unpin,{rpadding=15})self.toolbar.pin.onclick=function()self:_set_window_pinned(true)end
self.toolbar.unpin.onclick=function()self:_set_window_pinned(false)end
end
end
function BaseApp:_set_window_pinned(pinned)if rtk.has_js_reascript_api and self.toolbar.pin then
self.window:attr('pinned', pinned)self.toolbar.pin:attr('visible', not pinned)self.toolbar.unpin:attr('visible', pinned)end
end
function BaseApp:handle_onupdate()self:check_commands()end
function BaseApp:timeout_command_callbacks()local now=reaper.time_precise()for serial in pairs(self.cmdcallbacks)do
local expires,cb=table.unpack(self.cmdcallbacks[serial])if now>expires then
cb(nil)self.cmdcallbacks[serial]=nil
self.cmdpending=self.cmdpending-1
end
end
end
function BaseApp:send_command(appid,cmd,...)local cmdlist=reaper.GetExtState(appid, "command")if cmdlist then
if cmdlist:len()>200 then
log.warning("baseapp: %s not responding", appid)cmdlist=''else
cmdlist=cmdlist .. ' 'end
else
cmdlist=''end
local args={...}local callback=nil
local timeout=2
if #args >=1 and type(args[#args])=='function' then
callback=table.remove(args,#args)elseif #args >=2 and type(args[#args - 1])=='function' then
timeout=table.remove(args,#args)callback=table.remove(args,#args)end
if #args==0 then
args={0}end
if callback then
self.cmdserial=self.cmdserial+1
local serial=tostring(self.cmdserial)self.cmdcallbacks[serial]={reaper.time_precise()+timeout,callback}self.cmdpending=self.cmdpending+1
cmd=string.format('?%s:%s,%s', cmd, self.appid, serial)end
local joined=table.concat(args, ',')reaper.SetExtState(appid, "command", cmdlist .. cmd .. '=' .. joined, false)end
function BaseApp:handle_command(cmd,arg)if cmd=='ping' then
reaper.SetExtState(self.appid, "pong", arg, false)return arg
elseif cmd=='quit' then
self.window:close()end
end
function BaseApp:check_commands()if self.cmdpending>0 then
self:timeout_command_callbacks()end
if reaper.HasExtState(self.appid, "command") then
local val=reaper.GetExtState(self.appid, "command")reaper.DeleteExtState(self.appid, "command", false)for cmd, arg in val:gmatch('(%S+)=([^"]%S*)') do
if cmd:startswith('?') then
local cmd, return_appid, serial=cmd:match("%?([^:]+):([^,]+),(.*)")local response=self:handle_command(cmd,arg)self:send_command(return_appid, '!' .. serial, tostring(response))elseif cmd:startswith('!') then
local serial=cmd:match("!(.*)")local cbinfo=self.cmdcallbacks[serial]
if cbinfo then
self.cmdcallbacks[serial][2](arg)self.cmdcallbacks[serial]=nil
self.cmdpending=self.cmdpending-1
else
log.error("baseapp: %s received reply to unknown request %s", self.appid, serial)end
else
self:handle_command(cmd,arg)end
end
end
end
function BaseApp:handle_onclose()end
function BaseApp:handle_onkeypresspost(event)if event.handled then
return
end
if event.char == '=' and event.ctrl then
self:zoom(0.10)event:set_handled()elseif event.char=='-' and event.ctrl then
self:zoom(-0.10)event:set_handled()elseif event.char=='0' and event.ctrl then
self:zoom(0)event:set_handled()end
end
function BaseApp:handle_ondropfiles(event)end
function BaseApp:handle_onclick(event)if event.ctrl and event.button==rtk.mouse.BUTTON_MIDDLE then
self:zoom(0)event:set_handled()end
end
return BaseApp
end)()

local BaseApp=__mod_lib_baseapp
local rtk=rtk
__mod_rfx=(function()
local rtk=rtk
__mod_lib_binser=(function()
local assert=assert
local error=error
local select=select
local pairs=pairs
local getmetatable=getmetatable
local setmetatable=setmetatable
local type=type
local loadstring=loadstring or load
local concat=table.concat
local char=string.char
local byte=string.byte
local format=string.format
local sub=string.sub
local dump=string.dump
local floor=math.floor
local frexp=math.frexp
local unpack=unpack or table.unpack
if not frexp then
local log,abs,floor=math.log,math.abs,math.floor
local log2=log(2)frexp=function(x)if x==0 then return 0,0 end
local e=floor(log(abs(x))/log2+1)return x/2 ^ e,e
end
end
local function pack(...)return {...}, select("#", ...)end
local function not_array_index(x,len)return type(x) ~= "number" or x < 1 or x > len or x ~= floor(x)end
local function type_check(x,tp,name)assert(type(x)==tp,format("Expected parameter %q to be of type %q.", name, tp))end
local bigIntSupport=false
local isInteger
if math.type then
local mtype=math.type
bigIntSupport=loadstring[[
    local char = string.char
    return function(n)
        local nn = n < 0 and -(n + 1) or n
        local b1 = nn // 0x100000000000000
        local b2 = nn // 0x1000000000000 % 0x100
        local b3 = nn // 0x10000000000 % 0x100
        local b4 = nn // 0x100000000 % 0x100
        local b5 = nn // 0x1000000 % 0x100
        local b6 = nn // 0x10000 % 0x100
        local b7 = nn // 0x100 % 0x100
        local b8 = nn % 0x100
        if n < 0 then
            b1, b2, b3, b4 = 0xFF - b1, 0xFF - b2, 0xFF - b3, 0xFF - b4
            b5, b6, b7, b8 = 0xFF - b5, 0xFF - b6, 0xFF - b7, 0xFF - b8
        end
        return char(212, b1, b2, b3, b4, b5, b6, b7, b8)
    end]]()isInteger=function(x)return mtype(x)=='integer'end
else
isInteger=function(x)return floor(x)==x
end
end
local function number_to_str(n)if isInteger(n)then
if n<=100 and n>=-27 then
return char(n+27)elseif n<=8191 and n>=-8192 then
n=n+8192
return char(128+(floor(n/0x100)%0x100),n%0x100)elseif bigIntSupport then
return bigIntSupport(n)end
end
local sign=0
if n<0.0 then
sign=0x80
n=-n
end
local m,e=frexp(n)if m~=m then
return char(203,0xFF,0xF8,0x00,0x00,0x00,0x00,0x00,0x00)elseif m==1/0 then
if sign==0 then
return char(203,0x7F,0xF0,0x00,0x00,0x00,0x00,0x00,0x00)else
return char(203,0xFF,0xF0,0x00,0x00,0x00,0x00,0x00,0x00)end
end
e=e+0x3FE
if e<1 then
m=m*2 ^(52+e)e=0
else
m=(m*2-1)*2 ^ 52
end
return char(203,sign+floor(e/0x10),(e%0x10)*0x10+floor(m/0x1000000000000),floor(m/0x10000000000)%0x100,floor(m/0x100000000)%0x100,floor(m/0x1000000)%0x100,floor(m/0x10000)%0x100,floor(m/0x100)%0x100,m%0x100)end
local function number_from_str(str,index)local b=byte(str,index)if not b then error("Expected more bytes of input.") end
if b<128 then
return b-27,index+1
elseif b<192 then
local b2=byte(str,index+1)if not b2 then error("Expected more bytes of input.") end
return b2+0x100*(b-128)-8192,index+2
end
local b1,b2,b3,b4,b5,b6,b7,b8=byte(str,index+1,index+8)if(not b1)or(not b2)or(not b3)or(not b4)or
(not b5)or(not b6)or(not b7)or(not b8)then
error("Expected more bytes of input.")end
if b==212 then
local flip=b1>=128
if flip then
b1,b2,b3,b4=0xFF-b1,0xFF-b2,0xFF-b3,0xFF-b4
b5,b6,b7,b8=0xFF-b5,0xFF-b6,0xFF-b7,0xFF-b8
end
local n=((((((b1*0x100+b2)*0x100+b3)*0x100+b4)*0x100+b5)*0x100+b6)*0x100+b7)*0x100+b8
if flip then
return(-n)-1,index+9
else
return n,index+9
end
end
if b~=203 then
error("Expected number")end
local sign=b1>0x7F and-1 or 1
local e=(b1%0x80)*0x10+floor(b2/0x10)local m=((((((b2%0x10)*0x100+b3)*0x100+b4)*0x100+b5)*0x100+b6)*0x100+b7)*0x100+b8
local n
if e==0 then
if m==0 then
n=sign*0.0
else
n=sign*(m/2 ^ 52)*2 ^-1022
end
elseif e==0x7FF then
if m==0 then
n=sign*(1/0)else
n=0.0/0.0
end
else
n=sign*(1.0+m/2 ^ 52)*2 ^(e-0x3FF)end
return n,index+9
end
local function newbinser()local NEXT={}local CTORSTACK={}local mts={}local ids={}local serializers={}local deserializers={}local resources={}local resources_by_name={}local types={}types["nil"] = function(x, visited, accum)accum[#accum + 1]="\202"end
function types.number(x,visited,accum)accum[#accum+1]=number_to_str(x)end
function types.boolean(x,visited,accum)accum[#accum + 1]=x and "\204" or "\205"end
function types.string(x,visited,accum)local alen=#accum
if visited[x] then
accum[alen + 1]="\208"accum[alen+2]=number_to_str(visited[x])else
visited[x]=visited[NEXT]
visited[NEXT]=visited[NEXT]+1
accum[alen + 1]="\206"accum[alen+2]=number_to_str(#x)accum[alen+3]=x
end
end
local function check_custom_type(x,visited,accum)local res=resources[x]
if res then
accum[#accum + 1]="\211"types[type(res)](res,visited,accum)return true
end
local mt=getmetatable(x)local id=mt and ids[mt]
if id then
local constructing=visited[CTORSTACK]
if constructing[x] then
error("Infinite loop in constructor.")end
constructing[x]=true
accum[#accum + 1]="\209"types[type(id)](id,visited,accum)local args,len=pack(serializers[id](x))accum[#accum+1]=number_to_str(len)for i=1,len do
local arg=args[i]
types[type(arg)](arg,visited,accum)end
visited[x]=visited[NEXT]
visited[NEXT]=visited[NEXT]+1
constructing[x]=nil
return true
end
end
function types.userdata(x,visited,accum)if visited[x] then
accum[#accum + 1]="\208"accum[#accum+1]=number_to_str(visited[x])else
if check_custom_type(x,visited,accum)then return end
error("Cannot serialize this userdata.")end
end
function types.table(x,visited,accum)if visited[x] then
accum[#accum + 1]="\208"accum[#accum+1]=number_to_str(visited[x])else
if check_custom_type(x,visited,accum)then return end
visited[x]=visited[NEXT]
visited[NEXT]=visited[NEXT]+1
local xlen=#x
local mt=getmetatable(x)if mt then
accum[#accum + 1]="\213"types.table(mt,visited,accum)else
accum[#accum + 1]="\207"end
accum[#accum+1]=number_to_str(xlen)for i=1,xlen do
local v=x[i]
types[type(v)](v,visited,accum)end
local key_count=0
for k in pairs(x)do
if not_array_index(k,xlen)then
key_count=key_count+1
end
end
accum[#accum+1]=number_to_str(key_count)for k,v in pairs(x)do
if not_array_index(k,xlen)then
types[type(k)](k,visited,accum)types[type(v)](v,visited,accum)end
end
end
end
types["function"] = function(x, visited, accum)if visited[x] then
accum[#accum + 1]="\208"accum[#accum+1]=number_to_str(visited[x])else
if check_custom_type(x,visited,accum)then return end
visited[x]=visited[NEXT]
visited[NEXT]=visited[NEXT]+1
local str=dump(x)accum[#accum + 1]="\210"accum[#accum+1]=number_to_str(#str)accum[#accum+1]=str
end
end
types.cdata=function(x,visited,accum)if visited[x] then
accum[#accum + 1]="\208"accum[#accum+1]=number_to_str(visited[x])else
if check_custom_type(x,visited,#accum)then return end
error("Cannot serialize this cdata.")end
end
types.thread=function() error("Cannot serialize threads.") end
local function deserialize_value(str,index,visited)local t=byte(str,index)if not t then return nil,index end
if t<128 then
return t-27,index+1
elseif t<192 then
local b2=byte(str,index+1)if not b2 then error("Expected more bytes of input.") end
return b2+0x100*(t-128)-8192,index+2
elseif t==202 then
return nil,index+1
elseif t==203 or t==212 then
return number_from_str(str,index)elseif t==204 then
return true,index+1
elseif t==205 then
return false,index+1
elseif t==206 then
local length,dataindex=number_from_str(str,index+1)local nextindex=dataindex+length
if not (length >=0) then error("Bad string length") end
if #str < nextindex - 1 then error("Expected more bytes of string") end
local substr=sub(str,dataindex,nextindex-1)visited[#visited+1]=substr
return substr,nextindex
elseif t==207 or t==213 then
local mt,count,nextindex
local ret={}visited[#visited+1]=ret
nextindex=index+1
if t==213 then
mt,nextindex=deserialize_value(str,nextindex,visited)if type(mt) ~="table" then error("Expected table metatable") end
end
count,nextindex=number_from_str(str,nextindex)for i=1,count do
local oldindex=nextindex
ret[i],nextindex=deserialize_value(str,nextindex,visited)if nextindex==oldindex then error("Expected more bytes of input.") end
end
count,nextindex=number_from_str(str,nextindex)for i=1,count do
local k,v
local oldindex=nextindex
k,nextindex=deserialize_value(str,nextindex,visited)if nextindex==oldindex then error("Expected more bytes of input.") end
oldindex=nextindex
v,nextindex=deserialize_value(str,nextindex,visited)if nextindex==oldindex then error("Expected more bytes of input.") end
if k==nil then error("Can't have nil table keys") end
ret[k]=v
end
if mt then setmetatable(ret,mt)end
return ret,nextindex
elseif t==208 then
local ref,nextindex=number_from_str(str,index+1)return visited[ref],nextindex
elseif t==209 then
local count
local name,nextindex=deserialize_value(str,index+1,visited)count,nextindex=number_from_str(str,nextindex)local args={}for i=1,count do
local oldindex=nextindex
args[i],nextindex=deserialize_value(str,nextindex,visited)if nextindex==oldindex then error("Expected more bytes of input.") end
end
if not name or not deserializers[name] then
error(("Cannot deserialize class '%s'"):format(tostring(name)))end
local ret=deserializers[name](unpack(args))visited[#visited+1]=ret
return ret,nextindex
elseif t==210 then
local length,dataindex=number_from_str(str,index+1)local nextindex=dataindex+length
if not (length >=0) then error("Bad string length") end
if #str < nextindex - 1 then error("Expected more bytes of string") end
local ret=function() error("deserializing functions not supported") end
visited[#visited+1]=ret
return ret,nextindex
elseif t==211 then
local resname,nextindex=deserialize_value(str,index+1,visited)if resname==nil then error("Got nil resource name") end
local res=resources_by_name[resname]
if res==nil then
error(("No resources found for name '%s'"):format(tostring(resname)))end
return res,nextindex
else
error("Could not deserialize type byte " .. t .. ".")end
end
local function serialize(...)local visited={[NEXT]=1,[CTORSTACK]={}}local accum={}for i=1, select("#", ...) do
local x=select(i,...)types[type(x)](x,visited,accum)end
return concat(accum)end
local function make_file_writer(file)return setmetatable({},{__newindex=function(_,_,v)file:write(v)end
})end
local function serialize_to_file(path,mode,...)local file,err=io.open(path,mode)assert(file,err)local visited={[NEXT]=1,[CTORSTACK]={}}local accum=make_file_writer(file)for i=1, select("#", ...) do
local x=select(i,...)types[type(x)](x,visited,accum)end
file:flush()file:close()end
local function writeFile(path,...)return serialize_to_file(path, "wb", ...)end
local function appendFile(path,...)return serialize_to_file(path, "ab", ...)end
local function deserialize(str,index)assert(type(str)=="string", "Expected string to deserialize.")local vals={}index=index or 1
local visited={}local len=0
local val
while true do
local nextindex
val,nextindex=deserialize_value(str,index,visited)if nextindex>index then
len=len+1
vals[len]=val
index=nextindex
else
break
end
end
return vals,len
end
local function deserializeN(str,n,index)assert(type(str)=="string", "Expected string to deserialize.")n=n or 1
assert(type(n)=="number", "Expected a number for parameter n.")assert(n > 0 and floor(n)==n, "N must be a poitive integer.")local vals={}index=index or 1
local visited={}local len=0
local val
while len<n do
local nextindex
val,nextindex=deserialize_value(str,index,visited)if nextindex>index then
len=len+1
vals[len]=val
index=nextindex
else
break
end
end
vals[len+1]=index
return unpack(vals,1,n+1)end
local function readFile(path)local file, err=io.open(path, "rb")assert(file,err)local str=file:read("*all")file:close()return deserialize(str)end
local function registerResource(resource,name)type_check(name, "string", "name")assert(not resources[resource],"Resource already registered.")assert(not resources_by_name[name],format("Resource %q already exists.", name))resources_by_name[name]=resource
resources[resource]=name
return resource
end
local function unregisterResource(name)type_check(name, "string", "name")assert(resources_by_name[name], format("Resource %q does not exist.", name))local resource=resources_by_name[name]
resources_by_name[name]=nil
resources[resource]=nil
return resource
end
local function normalize_template(template)local ret={}for i=1,#template do
ret[i]=template[i]
end
local non_array_part={}for k in pairs(template)do
if not_array_index(k,#template)then
non_array_part[#non_array_part+1]=k
end
end
table.sort(non_array_part)for i=1,#non_array_part do
local name=non_array_part[i]
ret[#ret+1]={name,normalize_template(template[name])}end
return ret
end
local function templatepart_serialize(part,argaccum,x,len)local extras={}local extracount=0
for k,v in pairs(x)do
extras[k]=v
extracount=extracount+1
end
for i=1,#part do
local name
if type(part[i])=="table" then
name=part[i][1]
len=templatepart_serialize(part[i][2],argaccum,x[name],len)else
name=part[i]
len=len+1
argaccum[len]=x[part[i]]
end
if extras[name]~=nil then
extracount=extracount-1
extras[name]=nil
end
end
if extracount>0 then
argaccum[len+1]=extras
else
argaccum[len+1]=nil
end
return len+1
end
local function templatepart_deserialize(ret,part,values,vindex)for i=1,#part do
local name=part[i]
if type(name)=="table" then
local newret={}ret[name[1]]=newret
vindex=templatepart_deserialize(newret,name[2],values,vindex)else
ret[name]=values[vindex]
vindex=vindex+1
end
end
local extras=values[vindex]
if extras then
for k,v in pairs(extras)do
ret[k]=v
end
end
return vindex+1
end
local function template_serializer_and_deserializer(metatable,template)return function(x)local argaccum={}local len=templatepart_serialize(template,argaccum,x,0)return unpack(argaccum,1,len)end,function(...)local ret={}local args={...}templatepart_deserialize(ret,template,args,1)return setmetatable(ret,metatable)end
end
local function register(metatable,name,serialize,deserialize)if type(metatable)=="table" then
name=name or metatable.name
serialize=serialize or metatable._serialize
deserialize=deserialize or metatable._deserialize
if(not serialize)or(not deserialize)then
if metatable._template then
local t=normalize_template(metatable._template)serialize,deserialize=template_serializer_and_deserializer(metatable,t)else
registerResource(metatable,name)return
end
end
elseif type(metatable)=="string" then
name=name or metatable
end
type_check(name, "string", "name")type_check(serialize, "function", "serialize")type_check(deserialize, "function", "deserialize")assert((not ids[metatable])and(not resources[metatable]),"Metatable already registered.")assert((not mts[name])and(not resources_by_name[name]),("Name %q already registered."):format(name))mts[name]=metatable
ids[metatable]=name
serializers[name]=serialize
deserializers[name]=deserialize
return metatable
end
local function unregister(item)local name,metatable
if type(item)=="string" then
name,metatable=item,mts[item]
else
name,metatable=ids[item],item
end
type_check(name, "string", "name")mts[name]=nil
if(metatable)then
resources[metatable]=nil
ids[metatable]=nil
end
serializers[name]=nil
deserializers[name]=nil
resources_by_name[name]=nil;
return metatable
end
local function registerClass(class,name)name=name or class.name
if class.__instanceDict then
register(class.__instanceDict,name)else
register(class,name)end
return class
end
return {VERSION="0.0-8",s=serialize,d=deserialize,dn=deserializeN,r=readFile,w=writeFile,a=appendFile,serialize=serialize,deserialize=deserialize,deserializeN=deserializeN,readFile=readFile,writeFile=writeFile,appendFile=appendFile,register=register,unregister=unregister,registerResource=registerResource,unregisterResource=unregisterResource,registerClass=registerClass,newbinser=newbinser
}end
return newbinser()end)()
local binser=__mod_lib_binser
local json=__mod_lib_json
__mod_reabank=(function()
__mod_lib_crc64=(function()
local lut={0x0000000000000000,0x42f0e1eba9ea3693,0x85e1c3d753d46d26,0xc711223cfa3e5bb5,0x493366450e42ecdf,0x0bc387aea7a8da4c,0xccd2a5925d9681f9,0x8e224479f47cb76a,0x9266cc8a1c85d9be,0xd0962d61b56fef2d,0x17870f5d4f51b498,0x5577eeb6e6bb820b,0xdb55aacf12c73561,0x99a54b24bb2d03f2,0x5eb4691841135847,0x1c4488f3e8f96ed4,0x663d78ff90e185ef,0x24cd9914390bb37c,0xe3dcbb28c335e8c9,0xa12c5ac36adfde5a,0x2f0e1eba9ea36930,0x6dfeff5137495fa3,0xaaefdd6dcd770416,0xe81f3c86649d3285,0xf45bb4758c645c51,0xb6ab559e258e6ac2,0x71ba77a2dfb03177,0x334a9649765a07e4,0xbd68d2308226b08e,0xff9833db2bcc861d,0x388911e7d1f2dda8,0x7a79f00c7818eb3b,0xcc7af1ff21c30bde,0x8e8a101488293d4d,0x499b3228721766f8,0x0b6bd3c3dbfd506b,0x854997ba2f81e701,0xc7b97651866bd192,0x00a8546d7c558a27,0x4258b586d5bfbcb4,0x5e1c3d753d46d260,0x1cecdc9e94ace4f3,0xdbfdfea26e92bf46,0x990d1f49c77889d5,0x172f5b3033043ebf,0x55dfbadb9aee082c,0x92ce98e760d05399,0xd03e790cc93a650a,0xaa478900b1228e31,0xe8b768eb18c8b8a2,0x2fa64ad7e2f6e317,0x6d56ab3c4b1cd584,0xe374ef45bf6062ee,0xa1840eae168a547d,0x66952c92ecb40fc8,0x2465cd79455e395b,0x3821458aada7578f,0x7ad1a461044d611c,0xbdc0865dfe733aa9,0xff3067b657990c3a,0x711223cfa3e5bb50,0x33e2c2240a0f8dc3,0xf4f3e018f031d676,0xb60301f359dbe0e5,0xda050215ea6c212f,0x98f5e3fe438617bc,0x5fe4c1c2b9b84c09,0x1d14202910527a9a,0x93366450e42ecdf0,0xd1c685bb4dc4fb63,0x16d7a787b7faa0d6,0x5427466c1e109645,0x4863ce9ff6e9f891,0x0a932f745f03ce02,0xcd820d48a53d95b7,0x8f72eca30cd7a324,0x0150a8daf8ab144e,0x43a04931514122dd,0x84b16b0dab7f7968,0xc6418ae602954ffb,0xbc387aea7a8da4c0,0xfec89b01d3679253,0x39d9b93d2959c9e6,0x7b2958d680b3ff75,0xf50b1caf74cf481f,0xb7fbfd44dd257e8c,0x70eadf78271b2539,0x321a3e938ef113aa,0x2e5eb66066087d7e,0x6cae578bcfe24bed,0xabbf75b735dc1058,0xe94f945c9c3626cb,0x676dd025684a91a1,0x259d31cec1a0a732,0xe28c13f23b9efc87,0xa07cf2199274ca14,0x167ff3eacbaf2af1,0x548f120162451c62,0x939e303d987b47d7,0xd16ed1d631917144,0x5f4c95afc5edc62e,0x1dbc74446c07f0bd,0xdaad56789639ab08,0x985db7933fd39d9b,0x84193f60d72af34f,0xc6e9de8b7ec0c5dc,0x01f8fcb784fe9e69,0x43081d5c2d14a8fa,0xcd2a5925d9681f90,0x8fdab8ce70822903,0x48cb9af28abc72b6,0x0a3b7b1923564425,0x70428b155b4eaf1e,0x32b26afef2a4998d,0xf5a348c2089ac238,0xb753a929a170f4ab,0x3971ed50550c43c1,0x7b810cbbfce67552,0xbc902e8706d82ee7,0xfe60cf6caf321874,0xe224479f47cb76a0,0xa0d4a674ee214033,0x67c58448141f1b86,0x253565a3bdf52d15,0xab1721da49899a7f,0xe9e7c031e063acec,0x2ef6e20d1a5df759,0x6c0603e6b3b7c1ca,0xf6fae5c07d3274cd,0xb40a042bd4d8425e,0x731b26172ee619eb,0x31ebc7fc870c2f78,0xbfc9838573709812,0xfd39626eda9aae81,0x3a28405220a4f534,0x78d8a1b9894ec3a7,0x649c294a61b7ad73,0x266cc8a1c85d9be0,0xe17dea9d3263c055,0xa38d0b769b89f6c6,0x2daf4f0f6ff541ac,0x6f5faee4c61f773f,0xa84e8cd83c212c8a,0xeabe6d3395cb1a19,0x90c79d3fedd3f122,0xd2377cd44439c7b1,0x15265ee8be079c04,0x57d6bf0317edaa97,0xd9f4fb7ae3911dfd,0x9b041a914a7b2b6e,0x5c1538adb04570db,0x1ee5d94619af4648,0x02a151b5f156289c,0x4051b05e58bc1e0f,0x87409262a28245ba,0xc5b073890b687329,0x4b9237f0ff14c443,0x0962d61b56fef2d0,0xce73f427acc0a965,0x8c8315cc052a9ff6,0x3a80143f5cf17f13,0x7870f5d4f51b4980,0xbf61d7e80f251235,0xfd913603a6cf24a6,0x73b3727a52b393cc,0x31439391fb59a55f,0xf652b1ad0167feea,0xb4a25046a88dc879,0xa8e6d8b54074a6ad,0xea16395ee99e903e,0x2d071b6213a0cb8b,0x6ff7fa89ba4afd18,0xe1d5bef04e364a72,0xa3255f1be7dc7ce1,0x64347d271de22754,0x26c49cccb40811c7,0x5cbd6cc0cc10fafc,0x1e4d8d2b65facc6f,0xd95caf179fc497da,0x9bac4efc362ea149,0x158e0a85c2521623,0x577eeb6e6bb820b0,0x906fc95291867b05,0xd29f28b9386c4d96,0xcedba04ad0952342,0x8c2b41a1797f15d1,0x4b3a639d83414e64,0x09ca82762aab78f7,0x87e8c60fded7cf9d,0xc51827e4773df90e,0x020905d88d03a2bb,0x40f9e43324e99428,0x2cffe7d5975e55e2,0x6e0f063e3eb46371,0xa91e2402c48a38c4,0xebeec5e96d600e57,0x65cc8190991cb93d,0x273c607b30f68fae,0xe02d4247cac8d41b,0xa2dda3ac6322e288,0xbe992b5f8bdb8c5c,0xfc69cab42231bacf,0x3b78e888d80fe17a,0x7988096371e5d7e9,0xf7aa4d1a85996083,0xb55aacf12c735610,0x724b8ecdd64d0da5,0x30bb6f267fa73b36,0x4ac29f2a07bfd00d,0x08327ec1ae55e69e,0xcf235cfd546bbd2b,0x8dd3bd16fd818bb8,0x03f1f96f09fd3cd2,0x41011884a0170a41,0x86103ab85a2951f4,0xc4e0db53f3c36767,0xd8a453a01b3a09b3,0x9a54b24bb2d03f20,0x5d45907748ee6495,0x1fb5719ce1045206,0x919735e51578e56c,0xd367d40ebc92d3ff,0x1476f63246ac884a,0x568617d9ef46bed9,0xe085162ab69d5e3c,0xa275f7c11f7768af,0x6564d5fde549331a,0x279434164ca30589,0xa9b6706fb8dfb2e3,0xeb46918411358470,0x2c57b3b8eb0bdfc5,0x6ea7525342e1e956,0x72e3daa0aa188782,0x30133b4b03f2b111,0xf7021977f9cceaa4,0xb5f2f89c5026dc37,0x3bd0bce5a45a6b5d,0x79205d0e0db05dce,0xbe317f32f78e067b,0xfcc19ed95e6430e8,0x86b86ed5267cdbd3,0xc4488f3e8f96ed40,0x0359ad0275a8b6f5,0x41a94ce9dc428066,0xcf8b0890283e370c,0x8d7be97b81d4019f,0x4a6acb477bea5a2a,0x089a2aacd2006cb9,0x14dea25f3af9026d,0x562e43b4931334fe,0x913f6188692d6f4b,0xd3cf8063c0c759d8,0x5dedc41a34bbeeb2,0x1f1d25f19d51d821,0xd80c07cd676f8394,0x9afce626ce85b507,};
function crc64(s)local crc=0xfffffffffffffff
for i=1,#s do
local byte=string.byte(s,i)local t=((crc>>56)~ byte)&0xff
crc=(lut[t+1] ~(crc<<8))end
return crc
end
end)()

local rtk=rtk
local log=rtk.log
local reabank={DEFAULT_CHASE_CCS='1,2,11,64-69',reabank_filename_factory=nil,reabank_filename_user=nil,filename_tmp=nil,version=nil,banks_factory=nil,banks_by_guid={},legacy_banks_by_msblsb={},banks_by_path={},project_sync_queued=false,last_written_msblsb=nil,menu=nil,default_colors={['default'] = '#666666',['short'] = '#6c30c6',['short-light'] = '#9630c6',['short-dark'] = '#533bca',['legato'] = '#218561',['legato-dark'] = '#1c5e46',['legato-light'] = '#49ba91',['long'] = '#305fc6',['long-light'] = '#4474e1',['long-dark'] = '#2c4b94',['textured'] = '#9909bd',['fx'] = '#883333'},colors={},textcolors={['default'] = '#ffffff'}}Articulation=rtk.class('Articulation')Articulation.static.FLAG_CHASE=1<<0
Articulation.static.FLAG_ANTIHANG=1<<1
Articulation.static.FLAG_ANTIHANG_CC=1<<2
Articulation.static.FLAG_BLOCK_BANK_CHANGE=1<<3
Articulation.static.FLAG_TOGGLE=1<<4
Articulation.static.FLAG_HIDDEN=1<<5
Articulation.static.FLAG_IS_FILTER=1<<6
local function _parse_flags(flags,value)if not flags then
return value
end
for _, flag in ipairs(flags:split(',')) do
local negate=false
local mask=0
if flag:startswith("!") then
negate=true
flag=flag:sub(2)end
if flag=='chase' then
mask=Articulation.FLAG_CHASE
elseif flag=='antihang' then
mask=Articulation.FLAG_ANTIHANG
elseif flag=='antihangcc' then
mask=Articulation.FLAG_ANTIHANG_CC
elseif flag=='nobank' then
mask=Articulation.FLAG_BLOCK_BANK_CHANGE
elseif flag=='toggle' then
mask=Articulation.FLAG_TOGGLE
elseif flag=='hidden' then
mask=Articulation.FLAG_HIDDEN
end
if negate then
value=value&~mask
else
value=value|mask
end
end
return value
end
function Articulation:initialize(bank,program,name,attrs)self.color='default'self.channels=0
self.bank_guid=bank.guid
self.program=program
self.name=name
self._attrs=attrs
self._has_conditional_output=nil
table.merge(self,attrs)self.group=tonumber(self.group)or 1
self.spacer=tonumber(self.spacer)self.flags=_parse_flags(self.flags,bank.flags)self.buses=nil
end
function Articulation:has_transforms()return self.velrange or self.pitchrange or self.transpose or self.velocity
end
function Articulation:get_transforms()if self._transforms then
return self._transforms
end
local transforms={0,1.0,0,127,0,127}if self.transpose then
transforms[1]=tonumber(self.transpose)or 0
end
if self.velocity then
transforms[2]=tonumber(self.velocity)or 1
end
if self.pitchrange then
local min, max=self.pitchrange:match('(%d*)-?(%d*)')transforms[3]=tonumber(min)or 0
transforms[4]=tonumber(max)or 127
end
if self.velrange then
local min, max=self.velrange:match('(%d*)-?(%d*)')transforms[5]=tonumber(min)or 0
transforms[6]=tonumber(max)or 127
end
self._transforms=transforms
return transforms
end
function Articulation:get_outputs()if self._outputs then
return self._outputs
end
self.buses=0
self._has_conditional_output=false
self._outputs={}for spec in (self.outputs or ''):gmatch('([^/]+)') do
local output={type=nil,channel=nil,args={},route=true,filter_program=nil}for prefix, part in ('/' .. spec):gmatch('([/@:%%])([^@:%%]+)') do
if prefix=='/' then
if part:startswith('-') then
output.route=false
output.type=part:sub(2)else
output.type=part
end
elseif prefix=='@' then
if part=='-' then
output.route=false
output.channel=0
output.bus=0
else
if part:find('%.') then
local channel, bus=part:match('(%d*).(%d*)')output.channel=tonumber(channel)output.bus=tonumber(bus)if output.bus then
self.buses=self.buses|(1<<(output.bus-1))end
else
output.channel=tonumber(part)output.bus=nil
end
end
elseif prefix==':' then
output.args=part:split(',')elseif prefix=='%' then
output.filter_program=tonumber(part)self._has_conditional_output=true
end
end
self._outputs[#self._outputs+1]=output
end
return self._outputs
end
function Articulation:has_conditional_output()return self._has_conditional_output
end
function Articulation:describe_outputs()local outputs=self:get_outputs()local description=''local last_verb=nil
for n,output in ipairs(outputs)do
local s=nil
local verb='Sends'local channel=nil
if output.channel==0 then
channel='current channels'elseif output.channel then
channel=string.format('ch %d', output.channel)end
if output.bus then
channel=(channel and (channel .. ' ') or '') .. string.format('bus %s', output.bus)end
local args={tonumber(output.args[1]),tonumber(output.args[2])}if output.type=='program' then
s=string.format('program change %d', args[1] or 0)elseif output.type=='cc' then
s=string.format('CC %d val %d', args[1] or 0, args[2] or 0)elseif output.type == 'note' or output.type == 'note-hold' then
local note=args[1] or 0
local name=note_to_name(note)verb=output.type=='note' and 'Sends' or 'Holds'if(args[2] or 127)==127 then
s=string.format('note %s (%d)', name, note)else
s=string.format('note %s (%d) vel %d', name, note, args[2] or 127)end
elseif output.type=='pitch' then
s=string.format('pitch bend val %d', args[1] or 0)elseif output.type=='art' then
local program=args[1] or 0
local bank=self:get_bank()local art=bank.articulations_by_program[program]
if art then
s=art.name or 'unnamed articulation'else
s='undefined articulation'end
elseif output.type==nil and channel then
verb='Routes's=string.format('to %s', channel)end
if s then
if output.type and output.channel then
s=s .. string.format(' on %s', channel)end
if last_verb then
if verb==last_verb then
description=string.format('%s, %s', description, s)else
description=string.format('%s, %s %s', description, verb:lower(), s)end
else
description=string.format('%s %s', verb, s)end
last_verb=verb
end
end
return description
end
function Articulation:copy_to_bank(bank)local clone=Articulation(bank,self.program,self.name,self._attrs)bank:add_articulation(clone)end
function Articulation:get_bank()return reabank.get_bank_by_guid(self.bank_guid)end
function Articulation:is_active()return self.channels~=0
end
local Bank=rtk.class('Bank')function Bank:initialize(msb,lsb,name,attrs,factory)assert(name, 'bank name must be specified')self.factory=factory
self._msb=tonumber(msb)self._lsb=tonumber(lsb)if self._msb and self._lsb then
self.msblsb=(self._msb<<8)+self._lsb
end
self.name=name
self.realized=false
self.articulations={}self.articulations_by_program={}self.channel=17
table.merge(self,attrs)self._attrs=attrs
self.flags=_parse_flags(self.flags,Articulation.FLAG_CHASE|Articulation.FLAG_ANTIHANG|Articulation.FLAG_ANTIHANG_CC|Articulation.FLAG_BLOCK_BANK_CHANGE
)self.hidden=(self.flags&Articulation.FLAG_HIDDEN)~=0
self.flags=self.flags&~Articulation.FLAG_HIDDEN
self._cached_hash=nil
end
function Bank:_hash(dynamic)local arts={}log.time_start()for _,art in pairs(self.articulations_by_program)do
arts[#arts+1]=as_filtered_table(art.program,art.name,art.group,art.flags,art.iconname,art.spacer,art.message,art.color,art.outputs,art.velrange,art.pitchrange,art.transpose,art.velocity
)end
local bankinfo=as_filtered_table(self.name,self.shortname,self.group,self.flags,dynamic and (self.chase or '') or self:get_chase_cc_string(),self.clone,self.off,self.message,arts
)log.time_end('reabank: computed hash for %s', self.name)return crc64(table.tostring(bankinfo))end
function Bank:hash()if not self._cached_hash then
self._cached_hash=self:_hash(true)end
return self._cached_hash
end
function Bank:ensure_guid()if self.guid then
return
end
if self.msblsb then
local hash=string.format('%016x', self:_hash(false))local hash2=string.format('%016x', crc64(hash))local msb=self.msblsb>>8
self.guid=string.format('%s-%s-%s-%s-%s',msb >=92 and '22222222' or '11111111',hash2:sub(1,4),hash2:sub(5,8),hash:sub(1,4),hash:sub(5))else
self.guid=rtk.uuid4()end
for _,art in ipairs(self.articulations)do
art.bank_guid=self.guid
end
log.info('bank: missing GUID: %s %s', self.name, self.guid)return true
end
function Bank:get_current_msb_lsb()local msb,lsb=reabank.get_project_msblsb_for_guid(self.guid)if not msb then
log.exception('BUG: bank %s (guid=%s) missing from project state', self.name, self.guid)else
return msb,lsb
end
end
function Bank:add_articulation(art)art._index=#self.articulations+1
self.articulations[art._index]=art
self.articulations_by_program[art.program]=art
end
function Bank:get_articulation_by_program(program)return self.articulations_by_program[program]
end
function Bank:get_articulation_before(art)if art then
local idx=art._index-1
if idx>=1 then
return self.articulations[idx]
end
end
end
function Bank:get_articulation_after(art)if art then
local idx=art._index+1
if idx<=#self.articulations then
return self.articulations[idx]
end
end
end
function Bank:get_first_articulation()return self.articulations[1]
end
function Bank:get_last_articulation()return self.articulations[#self.articulations]
end
function Bank:get_src_channel(default_channel)if self.srcchannel==17 then
return default_channel
else
return self.srcchannel
end
end
function Bank:get_chase_cc_string()if self.chase then
return self.chase
end
local s=(app.config.chase_ccs or ''):gsub('%s', '')local valid=not s:find('[^%d,-]')if #s>0 and valid then
return s
else
return reabank.DEFAULT_CHASE_CCS
end
end
function Bank:get_chase_cc_list()if self._cached_chase then
return self._cached_chase
end
local ccs={}local chase=self:get_chase_cc_string()for _, elem in ipairs(chase:split(',')) do
if elem:find('-') then
local subrange=elem:split('-')for i=tonumber(subrange[1]),tonumber(subrange[2])do
ccs[#ccs+1]=i
end
else
ccs[#ccs+1]=tonumber(elem)end
end
self._cached_chase=ccs
return ccs
end
function Bank:get_path()if not self.group then
return self.shortname or self.name
else
return self.group .. '/' .. (self.shortname or self.name)end
end
function Bank:get_name_info()if not self.group then
return nil,nil,self.shortname
else
if not self.group:find('/') then
return nil,self.group,self.shortname
else
local vendor, product=self.group:match('([^/]+)/(.+)')return vendor,product,self.shortname
end
end
end
function Bank:copy_articulations_from(from_bank)for _,art in ipairs(from_bank.articulations)do
art:copy_to_bank(self)end
end
function Bank:copy_missing_attributes_from(from_bank)for k,v in pairs(from_bank._attrs)do
if not self._attrs[k] then
self._attrs[k]=v
self[k]=v
end
end
end
function Bank:realize()if self.realized then
return
end
for _,art in ipairs(self.articulations)do
local outputs=art:get_outputs()for _,output in ipairs(outputs)do
if output.filter_program then
local filter=self:get_articulation_by_program(output.filter_program)if filter then
filter.flags=filter.flags|Articulation.FLAG_IS_FILTER
end
end
end
end
self.realized=true
end
local function get_reabank_file()local ini=rtk.file.read(reaper.get_ini_file())return ini and ini:match("mididefbankprog=([^\n]*)")end
function reabank.init()log.time_start()reabank.last_written_msblsb=app:get_ext_state('last_written_msblsb')reabank.reabank_filename_factory=Path.join(Path.basedir, "Reaticulate-factory.reabank")reabank.reabank_filename_user=Path.join(Path.resourcedir, "Data", "Reaticulate.reabank")log.info("reabank: init files factory=%s user=%s", reabank.reabank_filename_factory, reabank.reabank_filename_user)local cur_factory_bank_size,err=rtk.file.size(reabank.reabank_filename_factory)local tmpfile=get_reabank_file() or ''local tmpnum=tmpfile:lower():match("-tmp(%d+).")if tmpnum and rtk.file.exists(tmpfile)then
log.debug("reabank: tmp file exists: %s", tmpfile)reabank.version=tonumber(tmpnum)reabank.filename_tmp=tmpfile
local last_factory_bank_size=reaper.GetExtState("reaticulate", "factory_bank_size")if cur_factory_bank_size==tonumber(last_factory_bank_size)then
reabank.menu=nil
reabank.parseall()log.info("reabank: parsed bank files (factory banks unchanged since last start)")log.time_end()return
else
log.info("reabank: factory bank has changed: cur=%s last=%s", cur_factory_bank_size, last_factory_bank_size)end
else
log.debug('reabank: previous tmp file is missing: %s', tmpfile)reabank.last_written_msblsb=nil
end
log.info("reabank: generating new reabank")reabank.parseall()reaper.SetExtState("reaticulate", "factory_bank_size", tostring(cur_factory_bank_size), true)log.info("reabank: refreshed reabank %s", reabank.filename_tmp)log.time_end()end
function reabank.onprojectchange()local state=app.project_state
if not state.msblsb_by_guid then
state.msblsb_by_guid={}end
end
function reabank.add_bank_to_project(bank,msb,lsb,required)local msblsb_by_guid=app.project_state.msblsb_by_guid
local msblsb=msblsb_by_guid[bank.guid]
if msblsb then
log.info('reabank: bank already exists in project with msb=%s lsb=%s', msblsb >> 8, msblsb & 0xff)return(msblsb>>8)&0xff,msblsb&0xff
end
log.info('reabank: add bank guid=%s msb=%s lsb=%s required=%s', bank.guid, msb, lsb, required)if msb and lsb then
local existing_guid=msblsb_by_guid[msb<<8|lsb]
if existing_guid and existing_guid~=bank.guid then
log.warning('reabank: requested msb/lsb %s,%s for bank %s conflicts with %s',msb,lsb,bank.name,existing_guid)msb=nil
lsb=nil
end
end
if not msb or not lsb then
if bank.msblsb then
msb=(bank.msblsb>>8)&0xff
lsb=bank.msblsb&0xff
log.debug('reabank: bank has defined msb=%s lsb=%s', msb, lsb)else
local crc=crc64(bank.guid)msb=(crc>>32)%64
lsb=(crc&0xffffffff)%128
log.debug('reabank: generated MSB/LSB from CRC: msb=%s lsb=%s', msb, lsb)end
end
local candidate=(msb<<8)|lsb
for i=0,16000 do
local found=false
for guid,msblsb in pairs(msblsb_by_guid)do
if msblsb==candidate and guid~=bank.guid then
found=true
break
end
end
if not found then
msblsb_by_guid[bank.guid]=candidate
break
else
if required then
log.info('reabank: failed to allocate requested msb/lsb (%s, %s) for bank %s',msb,lsb,bank.guid)return nil
end
candidate=candidate+1
if candidate>=(64<<8)then
candidate=(1<<8)|1
elseif(candidate&0xff)==0 then
candidate=candidate+1
end
end
end
app:queue(App.SAVE_PROJECT_STATE|App.REFRESH_BANKS|App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK)msb,lsb=candidate>>8,candidate&0xff
log.info('reabank: generated msblsb=%s,%s for bank %s', msb, lsb, bank.guid)return msb,lsb
end
function reabank.clear_chase_cc_list_cache()for guid,bank in pairs(reabank.banks_by_guid)do
bank._cached_chase=nil
bank._cached_hash=nil
end
end
function reabank.parse_colors(colors)for name, color in colors:gsub(',', ' '):gmatch('(%S+)=([^"]%S*)') do
reabank.colors[name]=color
end
end
local function parse_properties(line)local props={}for key, value in line:gmatch('(%w+)=([^"]%S*)') do
props[key]=value
end
for key, value in line:gmatch('(%w+)="([^"]*)"') do
props[key]=value:gsub('\\n', '\n'):gsub('&quot;', '"')end
return props
end
function reabank.parse(filename)local data,err=rtk.file.read(filename)if not data then
return
end
local factory=filename==reabank.reabank_filename_factory
local banks,dupes,dirty,outlines=reabank.parse_from_string(data,factory)log.info('reabank: read %s banks from %s', #banks, filename)if dirty then
log.info('reabank: rewriting %s with %s lines', filename, #outlines)local data=table.concat(outlines, '\n')err=rtk.file.write(filename,data)if err then
return app:fatal_error('Failed to rewrite updated Reaticulate reabank file after generating bank GUIDs: ' ..tostring(err))end
end
end
local function merge(t,k,v)if t[k]==nil then
t[k]=v
end
end
function reabank.parse_from_string(data,factory)if not data then
return {},{},false,nil
end
local dirty=false
local outlines={}local banks={}local dupes={}local bank=nil
local clones={}local function register(bank)if not bank then
return
end
local generated=bank:ensure_guid()if generated and bank.guid_line_number then
outlines[bank.guid_line_number] = string.format('//! id=%s', bank.guid)bank.guid_line_number=nil
end
local existing=reabank.get_bank_by_guid(bank.guid)if existing and not existing.factory then
log.error('reabank: bank %s has conflicting GUID (%s) with %s', bank.name, bank.guid, existing.name)dupes[#dupes+1]=bank
else
banks[#banks+1]=bank
reabank.register_bank(bank)end
return generated
end
local metadata={}for origline in data:gmatch("[^\n]*") do
local line=origline:gsub("^%s*(.-)%s*$", "%1")if line:startswith("Bank", true) then
dirty=register(bank)or dirty
local msb, lsb, name=line:match(".... +([%d*]+) +([%d*]+) +(.*)")local status
status,bank=xpcall(Bank,function()log.error('failed to load bank due to syntax error: %s', line)end,msb,lsb,name,metadata,factory
)if bank then
if not bank.guid then
outlines[#outlines + 1]='// generated guid goes here'bank.guid_line_number=#outlines
end
if bank.clone then
clones[#clones+1]=bank
end
outlines[#outlines+1]=origline:strip()metadata={}end
elseif line:startswith("//!") then
outlines[#outlines+1]=origline:strip()local props=parse_properties(line)merge(metadata, 'color', props.c)merge(metadata, 'iconname', props.i)merge(metadata, 'shortname', props.n)merge(metadata, 'group', props.g)merge(metadata, 'off', props.off and tonumber(props.off) or nil)merge(metadata, 'outputs', props.o)merge(metadata, 'flags', props.f)merge(metadata, 'message', props.m)merge(metadata, 'clone', props.clone)merge(metadata, 'chase', props.chase)merge(metadata, 'spacer', props.spacer)merge(metadata, 'guid', props.id)merge(metadata, 'velrange', props.velrange)merge(metadata, 'pitchrange', props.pitchrange)merge(metadata, 'transpose', props.transpose)merge(metadata, 'velocity', props.velocity)if props.colors then
reabank.parse_colors(props.colors)end
elseif line:len() > 0 and not line:startswith("//") then
local program, name=line:match("^ *(%d+) +(.*)")if bank and program and name then
outlines[#outlines+1]=origline:strip()local art=Articulation(bank,tonumber(program),name,metadata)if art.flags&Articulation.FLAG_HIDDEN==0 then
bank:add_articulation(art)end
end
metadata={}else
outlines[#outlines+1]=origline:strip()end
end
dirty=register(bank)or dirty
for _,bank in ipairs(clones)do
local source=reabank.banks_by_guid[bank.clone] or reabank.banks_by_path[bank.clone]
if source then
bank:copy_missing_attributes_from(source)bank:copy_articulations_from(source)end
end
log.debug('reabank: parsed banks sz=%d factory=%s', #data, factory)return banks,dupes,dirty,outlines
end
function reabank.parseall()reabank.banks_by_guid={}reabank.legacy_banks_by_msblsb={}reabank.banks_by_path={}if not reabank.banks_factory then
reabank.parse(reabank.reabank_filename_factory)reabank.banks_factory=table.shallow_copy(reabank.banks_by_guid)else
log.debug("skipping factory parse")for _,bank in pairs(reabank.banks_factory)do
reabank.register_bank(bank)end
end
reabank.parse(reabank.reabank_filename_user)end
function reabank.import_banks_from_string(data)local banks,dupes,dirty,outlines=reabank.parse_from_string(data,false)if #banks>0 then
for _,bank in ipairs(banks)do
if app.project_state.msblsb_by_guid[bank.guid] then
reabank.add_bank_to_project(bank)end
end
local filename=reabank.reabank_filename_user
local origdata,err=rtk.file.read(filename)local data=(origdata or '') .. '\n\n' .. table.concat(outlines, '\n')err=rtk.file.write(filename,data)if err then
log.error('reabank: failed to rewrite %s after import', filename)else
log.info('reabank: rewrote %s with %d new banks', filename, #banks)end
reabank.menu=nil
end
return banks,dupes
end
function reabank.import_banks_from_string_with_feedback(data,srcname)local banks,dupes=reabank.import_banks_from_string(data)local msg
if #banks>0 then
msg=string.format('%d banks were imported from %s:', #banks, srcname)for _,bank in ipairs(banks)do
msg=msg .. string.format('\n   - %s', bank.name)end
elseif #dupes==0 then
msg=string.format('No valid Reaticulate banks could be found in %s.', srcname)else
msg='No banks were imported.'end
if #dupes>0 then
msg=msg .. string.format('\n\n%d banks were ignored because they were already installed:', #dupes)for _,bank in ipairs(dupes)do
msg=msg .. string.format('\n   - %s', bank.name)end
end
if #banks>0 then
app:queue(App.REFRESH_BANKS)end
rtk.defer(reaper.ShowMessageBox, msg, 'Import Reaticulate Banks', 0)end
function reabank.register_bank(bank)reabank.banks_by_guid[bank.guid]=bank
reabank.banks_by_path[bank:get_path()]=bank
if bank.msblsb then
reabank.legacy_banks_by_msblsb[bank.msblsb]=bank
end
reabank.menu=nil
end
function reabank.create_user_reabank_if_missing()local f=io.open(reabank.reabank_filename_user)if f then
f:close()return
end
local inf=io.open(reabank.reabank_filename_factory)local outf=io.open(reabank.reabank_filename_user, 'w')for line in inf:lines()do
if line:startswith("//!") then
break
end
outf:write(line .. '\n')end
inf:close()outf:close()end
local function set_reabank_file(reabank)local inifile=reaper.get_ini_file()local ini,err=rtk.file.read(inifile)if err then
return app:fatal_error("Failed to read REAPER's ini file: " .. tostring(err))end
if ini:find("mididefbankprog=") then
ini = ini:gsub("mididefbankprog=[^\n]*", "mididefbankprog=" .. reabank)else
local pos=ini:find('%[REAPER%]\n')if not pos then
pos=ini:find('%[reaper%]\n')end
if pos then
ini = ini:sub(1, pos + 8) .. "mididefbankprog=" .. reabank .. "\n" .. ini:sub(pos + 9)end
end
log.info("reabank: updating ini file %s", inifile)err=rtk.file.write(inifile,ini)if err then
return app:fatal_error("Failed to write ini file: " .. tostring(err))end
end
function reabank.project_banks_to_reabank_string(compare)local changes={updates=0,additions=0}local msblsbmap={}local s=''local guids=table.keys(app.project_state.msblsb_by_guid)table.sort(guids)for _,guid in ipairs(guids)do
local msblsb=app.project_state.msblsb_by_guid[guid]
local bank=reabank.get_bank_by_guid(guid)if bank then
local msblsbstr=tostring(msblsb)local hash=bank:hash()if compare and compare[msblsbstr] then
if compare[msblsbstr]~=hash then
changes[bank.guid]=msblsb
changes.updates=changes.updates+1
end
else
changes.additions=changes.additions+1
end
msblsbmap[msblsbstr]=hash
local msb=msblsb>>8
local lsb=msblsb&0xff
s=s .. string.format('\n\nBank %d %d %s\n', msb, lsb, bank.name)for _,art in ipairs(bank.articulations)do
s=s .. string.format('%d %s\n', art.program, art.name)end
end
end
return msblsbmap,changes,s
end
function reabank.write_reabank_for_project()local msblsbmap=reabank.last_written_msblsb
local new_msblsbmap,changes,contents=reabank.project_banks_to_reabank_string(msblsbmap)if changes.updates==0 and changes.additions==0 then
log.info('reabank: project reabank has no changes/additions, skipping write')return
end
local tmpnum=1
if reabank.filename_tmp then
tmpnum=tonumber(reabank.filename_tmp:match("-tmp(%d+).")) + 1
end
local newfile=reabank.reabank_filename_user:gsub("(.*).reabank", "%1-tmp" .. tmpnum .. ".reabank")contents="// Generated file.  DO NOT EDIT!  CONTENTS WILL BE LOST!\n" .."// Edit this instead: " .. reabank.reabank_filename_user .. "\n\n\n\n" ..contents
if not msblsbmap and reabank.filename_tmp then
local existing=rtk.file.read(reabank.filename_tmp)if existing==contents then
log.debug('reabank: project reabank contents is not changing, skipping write')return
end
end
log.debug('reabank: stringified banks nbytes=%s', #contents)local err=rtk.file.write(newfile,contents)if err then
return app:fatal_error("Failed to write project Reabank file: " .. tostring(err))end
log.debug('reabank: wrote %s', newfile)set_reabank_file(newfile)log.debug('reabank: installed new Reaper global reabank')if reabank.filename_tmp and rtk.file.exists(reabank.filename_tmp)then
log.debug("reabank: deleting old reabank file: %s", reabank.filename_tmp)os.remove(reabank.filename_tmp)end
reabank.filename_tmp=newfile
log.info("reabank: finished switching to new reabank file: %s", newfile)reabank.version=tmpnum
app:set_ext_state('last_written_msblsb', new_msblsbmap, true)reabank.last_written_msblsb=new_msblsbmap
return changes.updates>0 and changes or nil,changes.additions>0
end
function reabank.get_bank_by_guid(guid)return reabank.banks_by_guid[guid]
end
function reabank.get_legacy_bank_by_msblsb(msblsb)return reabank.legacy_banks_by_msblsb[math.floor(tonumber(msblsb)or 0)]
end
function reabank.get_project_msblsb_for_guid(guid)local msblsb=app.project_state.msblsb_by_guid[guid]
if msblsb then
return(msblsb>>8)&0xff,msblsb&0xff
end
end
function reabank.to_menu()if reabank.menu then
return reabank.menu
end
local bankmenu={}for _,bank in pairs(reabank.banks_by_guid)do
local submenu=bankmenu
if bank.group then
local group=(bank.factory and 'Factory/' or 'User/') .. bank.group
for part in group:gmatch("[^/]+") do
local lowerpart=part:lower()local found=false
for n,tmpmenu in ipairs(submenu)do
if tmpmenu.lowername==lowerpart then
submenu=tmpmenu.submenu
found=true
break
end
end
if not found then
local tmpmenu={part,submenu={},lowername=lowerpart}submenu[#submenu+1]=tmpmenu
submenu=tmpmenu.submenu
end
end
end
submenu[#submenu+1]={bank.shortname or bank.name,id=bank.guid,disabled=bank.hidden,altlabel=bank.name
}end
local function cmp(a,b)return a[1]<b[1]
end
local function sort(t)for _,menu in pairs(t)do
if menu.submenu then
sort(menu.submenu)end
end
table.sort(t,cmp)end
sort(bankmenu)reabank.menu=bankmenu
return bankmenu
end
return reabank
end)()

local reabank=__mod_reabank
local log=rtk.log
local NO_PROGRAM=128
local rfx={MAGIC=42<<24,OPCODE_NOOP=0,OPCODE_CLEAR=1,OPCODE_ACTIVATE_ARTICULATION=2,OPCODE_NEW_ARTICULATION=3,OPCODE_ADD_ARTICULATION_EXTENSION=4,OPCODE_ADD_OUTPUT_EVENT=5,OPCODE_ADD_OUTPUT_EVENT_EXTENSION=6,OPCODE_SYNC_TO_FEEDBACK_CONTROLLER=7,OPCODE_SET_CC_FEEDBACK_ENABLED=8,OPCODE_NEW_BANK=9,OPCODE_SET_BANK_CHASE_CC=10,OPCODE_FINALIZE_ARTICULATIONS=11,OPCODE_SET_APPDATA=12,OPCODE_CLEAR_ARTICULATION=13,OPCODE_ADVANCE_HISTORY=14,OPCODE_UPDATE_CURRENT_CCS=15,OPCODE_SUBSCRIBE=16,OPCODE_SET_CUSTOM_FEEDBACK_MIDI_BYTES=17,GMEM_GIDX_MAGIC=0,GMEM_GIDX_VERSION=1,GMEM_GIDX_SERIAL=2,GMEM_GIDX_ID_BITMAP_OFFSET=3,GMEM_GIDX_DEFAULT_CHANNEL=4,GMEM_GIDX_RFX_OFFSET=5,GMEM_GIDX_RFX_STRIDE=6,GMEM_GIDX_OPCODES_OFFSET=20,GMEM_GIDX_APP_DATA_OFFSET=21,GMEM_GIDX_INSTANCE_DATA_OFFSET=22,GMEM_GIDX_SUBSCRIPTION_OFFSET=23,GMEM_VERSION=1,GMEM_MAGIC=0xbadc0de,GMEM_ID_BITMAP_OFFSET=1000,GMEM_RFX_OFFSET=2000,GMEM_RFX_STRIDE=3000,GMEM_IIDX_INSTANCE_ID=0,GMEM_IIDX_SERIAL=1,GMEM_IIDX_PONG=2,GMEM_IIDX_INSTANCE_DATA_SUBSCRIPTION=3,GMEM_IIDX_OPCODES=100,GMEM_IIDX_APP_DATA=1000,GMEM_IIDX_INSTANCE_DATA=2000,GMEM_OPCODES_BUFFER_SIZE=1000-100,GMEM_APP_DATA_BUFFER_SIZE=2000-1000,ERROR_NONE=nil,ERROR_MISSING_RFX=1,ERROR_TRACK_FX_BYPASSED=2,ERROR_RFX_BYPASSED=3,ERROR_BAD_MAGIC=4,ERROR_UNSUPPORTED_VERSION=5,ERROR_DESERIALIZATION_FAILED=6,ERROR_DUPLICATE_BANK=1,ERROR_BUS_CONFLICT=2,ERROR_PROGRAM_CONFLICT=3,ERROR_UNKNOWN_BANK=4,MAX_BANKS=16,SUBSCRIPTION_NONE=0,SUBSCRIPTION_CC=1<<0,SUBSCRIPTION_NOTES=1<<1,params_by_version={[1]={metadata=0,gmem_index=1,instance_id=3,history_serial=61,opcode=63,active_notes=2,control_start=9,control_end=24,group_4_enabled_programs=25,banks_start=29,banks_end=40,}},last_gmem_gc_time=0,last_instance_num=0,global_serial=0,rfx_awaiting_commit=nil,active_notes=0,onartchange=function(channel,group,last,current,track_changed)end,onnoteschange=function(old,new)end,onccchange=function()end,onhashchange=function()end,onunsubscribe=function()end,state={depth=0,tracks={},global_automation_override=nil,last_touched_fx={track=nil,automation_mode=nil,param=nil,fx=nil,deferred=false,}}}local output_type_to_rfx_param={["none"] = 0,["program"] = 1,["cc"] = 2,["note"] = 3,["note-hold"] = 4,["art"] = 5,["pitch"] = 6,}function rfx.init()rfx.global_serial=os.time()reaper.gmem_attach('reaticulate')reaper.gmem_write(rfx.GMEM_GIDX_SERIAL,rfx.global_serial)reaper.gmem_write(rfx.GMEM_GIDX_ID_BITMAP_OFFSET,rfx.GMEM_ID_BITMAP_OFFSET)reaper.gmem_write(rfx.GMEM_GIDX_RFX_OFFSET,rfx.GMEM_RFX_OFFSET)reaper.gmem_write(rfx.GMEM_GIDX_RFX_STRIDE,rfx.GMEM_RFX_STRIDE)reaper.gmem_write(rfx.GMEM_GIDX_OPCODES_OFFSET,rfx.GMEM_IIDX_OPCODES)reaper.gmem_write(rfx.GMEM_GIDX_APP_DATA_OFFSET,rfx.GMEM_IIDX_APP_DATA)reaper.gmem_write(rfx.GMEM_GIDX_INSTANCE_DATA_OFFSET,rfx.GMEM_IIDX_INSTANCE_DATA)reaper.gmem_write(rfx.GMEM_GIDX_SUBSCRIPTION_OFFSET,rfx.GMEM_IIDX_INSTANCE_DATA_SUBSCRIPTION)reaper.gmem_write(rfx.GMEM_GIDX_VERSION,rfx.GMEM_VERSION)reaper.gmem_write(rfx.GMEM_GIDX_MAGIC,rfx.GMEM_MAGIC)rfx.current=rfx.Track()end
function rfx.get(track)if reaper.ValidatePtr2(0, track, "MediaTrack*") then
return reaper.TrackFX_GetByName(track, "Reaticulate", false)end
end
function rfx.is_audio_device_open()local r, _=reaper.GetAudioDeviceInfo('MODE', '')return r
end
function rfx.validate(track,fx)if fx==nil or fx==-1 then
return nil,nil,nil,nil,nil,rfx.ERROR_MISSING_RFX
end
local r,_,_=reaper.TrackFX_GetParam(track,fx,0)if r<0 then
return nil,nil,nil,nil,nil,rfx.ERROR_MISSING_RFX
end
if reaper.GetMediaTrackInfo_Value(track, "I_FXEN") ~= 1 then
return nil,nil,nil,nil,nil,rfx.ERROR_TRACK_FX_BYPASSED
end
if not reaper.TrackFX_GetEnabled(track,fx)or reaper.TrackFX_GetOffline(track,fx)then
return nil,nil,nil,nil,nil,rfx.ERROR_RFX_BYPASSED
end
local metadata=math.floor(r)local magic=metadata&0xff000000
if magic~=rfx.MAGIC then
return nil,nil,nil,nil,nil,rfx.ERROR_BAD_MAGIC
end
local version=(metadata&0x00ff0000)>>16
local params=rfx.params_by_version[version]
if params==nil then
return nil,nil,nil,nil,nil,rfx.ERROR_UNSUPPORTED_VERSION
end
local gmem_index,_,_=reaper.TrackFX_GetParam(track,fx,params.gmem_index)if gmem_index==0 then
log.warning("rfx: instance missing gmem_index")return nil,nil,nil,nil,nil,rfx.ERROR_MISSING_RFX
end
return fx,metadata,version,params,gmem_index,nil
end
function rfx.gc(force)if reaper.gmem_read(rfx.GMEM_ID_BITMAP_OFFSET+30)&0xffffffff~=0xffffffff and not force then
return
end
local now=reaper.time_precise()if now-rfx.last_gmem_gc_time<30 and not force then
return
end
rfx.last_gmem_gc_time=now
log.time_start()local slots={}for pidx=0,100 do
local proj, _=reaper.EnumProjects(pidx, '')if not proj then
break
end
for tidx=0,reaper.CountTracks(proj)-1 do
local track=reaper.GetTrack(proj,tidx)local fx=rfx.get(track)local fx,metadata,version,error=rfx.validate(track,fx)if fx then
local params=rfx.params_by_version[version]
local id,_,_=reaper.TrackFX_GetParam(track,fx,params.instance_id)local idx=math.floor(id/32)local bit=(1<<(id%32))if(slots[idx] or 0)&bit==0 then
slots[idx]=(slots[idx] or 0)|bit
else
log.error('BUG: track %s does not have a unique Reaticulate instance id!', track)end
end
end
end
for i=0,100 do
local bitmap=reaper.gmem_read(rfx.GMEM_ID_BITMAP_OFFSET+i)&0xffffffff
if(bitmap==0xffffffff and slots[i]~=0xffffffff)or(force and slots[i] and bitmap~=slots[i])then
log.debug('rfx: gc slot %d: %x != %x', i, bitmap, slots[i] or 0)reaper.gmem_write(rfx.GMEM_ID_BITMAP_OFFSET+i,slots[i] or 0)end
end
log.debug('rfx: gc complete')log.time_end()end
function rfx.set_gmem_global_default_channel(channel)reaper.gmem_write(rfx.GMEM_GIDX_DEFAULT_CHANNEL,channel-1)end
function rfx.opcode(opcode,args,track,fx,gmem_index,opcode_param,do_commit)local offset=gmem_index+rfx.GMEM_IIDX_OPCODES
if not offset then
return log.exception("rfx: opcode() called on track without valid RFX")end
local n_committed=reaper.gmem_read(offset)if n_committed>0 then
rfx.opcode_flush(track,fx,gmem_index,opcode_param)if not rfx.is_audio_device_open()then
log.error('reaticulate: audio device is closed, some functionality will not work')else
log.warning("rfx: %s committed opcodes during enqueue, forced a flush", n_committed)log.trace(log.INFO)end
n_committed=reaper.gmem_read(offset)if n_committed>0 then
return log.critical("rfx: opcode flush did not seem to work")end
end
local argc=args and #args or 0
local queue_size=reaper.gmem_read(offset+1)if 2+queue_size+1+argc>=rfx.GMEM_OPCODES_BUFFER_SIZE then
rfx.opcode_flush(track,fx,gmem_index,opcode_param)queue_size=0
end
local opidx=offset+2+queue_size
reaper.gmem_write(opidx,opcode|(argc<<8))for i=1,argc do
reaper.gmem_write(opidx+i,args[i])end
reaper.gmem_write(offset+1,queue_size+1+argc)if do_commit~=false then
rfx._queue_commit(track,fx,nil,gmem_index)end
end
function rfx.opcode_on_track(track,opcode,args)local fx,_,_,params,gmem_index,_=rfx.validate(track,rfx.get(track))if fx then
rfx.opcode(opcode,args,track,fx,gmem_index,params.opcode)return true
else
return false
end
end
function rfx._queue_commit(track,fx,appdata,gmem_index)gmem_index=tostring(gmem_index)if rfx.rfx_awaiting_commit==nil then
rfx.rfx_awaiting_commit={[gmem_index]={track,fx,appdata}}else
local t=rfx.rfx_awaiting_commit[gmem_index]
if t==nil then
rfx.rfx_awaiting_commit[gmem_index]={track,fx,appdata}else
t[2]=fx or t[2]
t[3]=appdata or t[3]
end
end
end
function rfx._opcode_commit(track,fx,gmem_index)if gmem_index==nil then
log.exception('_opcode_commit given nil offset')return
end
local offset=gmem_index+rfx.GMEM_IIDX_OPCODES
local n_buffered=reaper.gmem_read(offset+1)log.debug('rfx: commit opcodes gmem_index=%s n=%s first=%s', gmem_index, n_buffered, reaper.gmem_read(offset + 2))reaper.gmem_write(offset+1,0)reaper.gmem_write(offset,n_buffered)rfx.rfx_awaiting_commit[gmem_index]=nil
end
function rfx.opcode_commit_all()if rfx.rfx_awaiting_commit~=nil then
for gmem_index,trackfx in pairs(rfx.rfx_awaiting_commit)do
local track,fx,appdata=table.unpack(trackfx)if reaper.ValidatePtr2(0, track, "MediaTrack*") then
if appdata then
rfx._write_appdata(track,appdata)end
if fx then
rfx._opcode_commit(track,fx,gmem_index)end
end
end
rfx.rfx_awaiting_commit=nil
end
end
function rfx.opcode_flush(track,fx,gmem_index,opcode_param)if not reaper.ValidatePtr2(0, track, "MediaTrack*") then
return
end
if rfx.rfx_awaiting_commit then
rfx._opcode_commit(track,fx,gmem_index)end
rfx.push_state(track)reaper.TrackFX_SetParam(track,fx,opcode_param,42)rfx.pop_state()end
function rfx._write_appdata(track,appdata)local data='2' .. (appdata and json.encode(appdata) or '')reaper.GetSetMediaTrackInfo_String(track, 'P_EXT:reaticulate', data, true)reaper.MarkProjectDirty(0)log.info('rfx: wrote %s bytes of track appdata', #data)end
function rfx.push_state(track)local state=rfx.state
local track_mode=0
if track and reaper.ValidatePtr2(0, track, "MediaTrack*") then
track_mode=reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE")end
state.depth=state.depth+1
if state.depth==1 then
state.global_automation_override=reaper.GetGlobalAutomationOverride()local last=state.last_touched_fx
local lr,ltracknum,lfx,lparam=reaper.GetLastTouchedFX()if lr then
if ltracknum>0 then
last.track=reaper.GetTrack(0,ltracknum-1)else
last.track=reaper.GetMasterTrack(0)end
if reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
last.fx=lfx
local val,_,_=reaper.TrackFX_GetParam(last.track,lfx,0)if val<0 or(math.floor(val)&0xff000000)~=rfx.MAGIC then
last.param=lparam
last.rfx=false
else
last.param=61
last.rfx=true
end
last.automation_mode=reaper.GetMediaTrackInfo_Value(last.track, "I_AUTOMODE")if last.automation_mode>1 then
state.tracks[last.track]=last.automation_mode
reaper.SetMediaTrackInfo_Value(last.track, "I_AUTOMODE", 0)end
else
last.track=nil
end
elseif track_mode<=1 then
return
else
last.track=nil
end
reaper.PreventUIRefresh(1)if state.global_automation_override>1 then
reaper.SetGlobalAutomationOverride(-1)end
end
if track_mode>1 and state.tracks[track]==nil then
state.tracks[track]=track_mode
reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", 0)end
end
function rfx.pop_state()local state=rfx.state
if state.depth==0 then
return
end
state.depth=state.depth-1
if state.depth>0 then
return
end
local last=state.last_touched_fx
if last.track and reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
if last.automation_mode>1 then
reaper.SetMediaTrackInfo_Value(last.track, "I_AUTOMODE", 0)end
local function restore()if last.track and reaper.ValidatePtr2(0, last.track, "MediaTrack*") then
local lastval,_,_=reaper.TrackFX_GetParam(last.track,last.fx,last.param)reaper.TrackFX_SetParam(last.track,last.fx,last.param,lastval)end
last.deferred=false
last.track=nil
end
if last.rfx or last.track~=rfx.current.track then
restore()elseif not last.deferred then
last.deferred=true
rtk.defer(restore)end
else
last.track=nil
end
for track,mode in pairs(state.tracks)do
reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", mode)state.tracks[track]=nil
end
if state.global_automation_override>1 then
reaper.SetGlobalAutomationOverride(state.global_automation_override)end
reaper.PreventUIRefresh(-1)end
function rfx.get_tracks(project,include_disabled)project=project or 0
local rfxtrack=rfx.Track()local ntracks=reaper.CountTracks(project)local idx=0
return function()while idx<ntracks do
local track=reaper.GetTrack(project,idx)idx=idx+1
if rfxtrack:presync(track)then
return idx,rfxtrack
elseif(rfxtrack.error==rfx.ERROR_TRACK_FX_BYPASSED or
rfxtrack.error==rfx.ERROR_RFX_BYPASSED)and
include_disabled then
return idx,rfxtrack
end
end
end
end
function rfx.get_track(track)if not reaper.ValidatePtr2(0, track, 'MediaTrack*') then
return
end
local rfxtrack=rfx.Track()rfxtrack:presync(track)return rfxtrack
end
function rfx.all_tracks_sync_banks_if_hash_changed()log.time_start()reaper.Undo_BeginBlock2(0)for idx,rfxtrack in rfx.get_tracks(0,true)do
assert(not rfxtrack.banks_by_channel)rfxtrack:sync_banks_if_hash_changed()end
reaper.Undo_EndBlock2(0, "Reaticulate: update track banks (cannot be undone)", UNDO_STATE_FX)log.time_end('rfx: done resyncing RFX on all tracks')end
rfx.GUIDMigrator=rtk.class('rfx.GUIDMigrator')function rfx.GUIDMigrator:initialize(track)self.track=track
self.msblsbmap={}self.conversion_needed=false
end
function rfx.GUIDMigrator:migrate_bankinfo(bankinfo)local msb,lsb
if not bankinfo.t then
local src,dst=bankinfo[1],bankinfo[2]
msb,lsb=tonumber(bankinfo[3])or 0,tonumber(bankinfo[4])or 0
while #bankinfo>0 do
table.remove(bankinfo)end
bankinfo.src=src
bankinfo.dst=dst
bankinfo.v=(msb<<8)|lsb
elseif bankinfo.t=='b' then
local v=tonumber(bankinfo.v)or 0
msb,lsb=v>>8,v&0xff
else
return
end
local bank=reabank.get_legacy_bank_by_msblsb(bankinfo.v)if not bank then
log.warning('rfx: bank %s/%s could not be found for migration', msb, lsb)return
else
bankinfo.name=bank.name
end
if bank.guid then
bankinfo.t='g'bankinfo.v=bank.guid
self.track:queue_write_appdata()self:add_bank_to_project(bank,msb,lsb)else
log.error('rfx: migration failed: bank %s is missing GUID', bank.name)end
return bank
end
function rfx.GUIDMigrator:add_bank_to_project(bank,msb,lsb)local gotmsb,gotlsb=reabank.add_bank_to_project(bank,msb,lsb)if(msb or lsb)and(gotmsb~=msb or gotlsb~=lsb)then
if self.msblsbmap[msb] then
self.msblsbmap[msb][lsb]={gotmsb,gotlsb,bank}else
self.msblsbmap[msb]={[lsb]={gotmsb,gotlsb,bank}}end
self.conversion_needed=true
end
log.info('rfx: migrate MSB/LSB bank reference to GUID: %s (%s/%s -> %s/%s)',bank.name,msb,lsb,gotmsb,gotlsb)return gotmsb,gotlsb
end
function rfx.GUIDMigrator:remap_bank_select()if not self.conversion_needed then
return
end
remap_bank_select_multiple(self.track.track,self.msblsbmap)end
rfx.Track=rtk.class('rfx.Track')function rfx.Track:initialize()self.metadata=nil
self.version=nil
self.serial=nil
self.params=nil
self.gmem_index=nil
self.appdata=nil
self.unknown_banks=nil
self.programs={}self.banks_by_channel=nil
self:reset()end
function rfx.Track:reset()self.track=nil
self.fx=nil
self.error=nil
for channel=1,16 do
self.programs[channel]={NO_PROGRAM,NO_PROGRAM,NO_PROGRAM,NO_PROGRAM}end
end
function rfx.Track:_sync_params(track,fx)local fx,metadata,version,params,gmem_index,error=rfx.validate(track,fx)if error then
self.error=error
return nil
end
if version~=self.version then
self.version=version
self.params=params
end
self.gmem_index=gmem_index
self.metadata=metadata
return fx
end
function rfx.Track:presync(track,forced,unsubscribe)local last_track=self.track
local last_fx=self.fx
local track_changed=(track~=last_track)or forced
if unsubscribe and track_changed and last_track and last_fx then
rfx.onunsubscribe()self:subscribe(rfx.SUBSCRIPTION_NONE)end
self.track=track
self.error=rfx.ERROR_NONE
if not track then
self.fx=nil
return nil,track_changed,false
end
local candidate_fx=rfx.get(track)local fx=self:_sync_params(track,candidate_fx)track_changed=track_changed or(fx~=self.fx)local metadata=self.metadata or 0
local serial=metadata&0xff;
local serial_changed=self.serial~=serial or track_changed
self.serial=serial
self.fx=fx
local migrated=false
if track_changed then
self.banks_by_channel=nil
if candidate_fx and candidate_fx~=-1 then
self.appdata=self:_read_appdata()end
if fx then
if type(self.appdata) ~='table' or not self.appdata.banks then
if self:get_param(self.params.banks_start)~=0 then
self:migrate_to_appdata()migrated=true
else
self:_init_appdata()end
end
end
end
return fx,track_changed,serial_changed,migrated
end
function rfx.Track:sync(track,forced)local fx,track_changed,serial_changed,migrated=self:presync(track,forced,true)if not track or not fx then
return track_changed
end
if track_changed then
self:subscribe(rfx.SUBSCRIPTION_NOTES)if self:index_banks_by_channel_and_check_hash()or migrated then
log.info("rfx: resyncing banks due to hash mismatch")if self==rfx.current then
rfx.onhashchange()end
self:sync_banks_to_rfx()end
rfx.onccchange()rfx.gc()end
if serial_changed then
local offset=self.gmem_index+rfx.GMEM_IIDX_INSTANCE_DATA
local change_bitmap=reaper.gmem_read(offset)if change_bitmap>0 then
reaper.gmem_write(offset,0)end
if change_bitmap&(1<<2)~=0 or track_changed then
local info=reaper.gmem_read(offset+2)local programs_offset=info&0xffff
local len=info>>16
for channel=1,16 do
for group=1,len/16 do
local program_offset=((group-1)*16)+(channel-1)local program=reaper.gmem_read(offset+programs_offset+program_offset)local last_program=self.programs[channel][group]
if(track_changed and program~=NO_PROGRAM)or last_program~=program then
rfx.onartchange(channel,group,last_program,program,track_changed)end
self.programs[channel][group]=program
end
end
end
if change_bitmap&(1<<1)~=0 then
local notes_offset=reaper.gmem_read(offset+1)&0xffff
local last_notes=rfx.active_notes
rfx.active_notes=reaper.gmem_read(offset+notes_offset)if rfx.active_notes~=last_notes then
rfx.onnoteschange(last_notes,rfx.active_notes)end
end
if change_bitmap&(1<<3)~=0 then
rfx.onccchange()end
end
return track_changed
end
function rfx.Track:valid()return self.fx~=nil
end
function rfx.Track:get_cc_value(cc)local offset=self.gmem_index+rfx.GMEM_IIDX_INSTANCE_DATA
local cc_offset=reaper.gmem_read(offset+3)&0xffff
return reaper.gmem_read(offset+cc_offset+cc)end
function rfx.Track:_init_appdata()self.appdata={v=1,banks={}}self:queue_write_appdata()end
function rfx.Track:migrate_to_appdata()log.debug('migrating old RFX version to use appdata')if type(self.appdata) ~='table' then
self.appdata={v=1}end
self.appdata.banks={}for param=self.params.banks_start,self.params.banks_end do
local b0,b1,b2,b3=self:get_data(param)if b2>0 and b3>0 then
local msblsb=(b2<<8)|b3
local bank=reabank.get_legacy_bank_by_msblsb(msblsb)if not bank then
log.warning('unable to migrate unknown bank msb=%d lsb=%d', b2, b3)end
local hash=bank and bank:hash()or nil
assert(not bank or bank.guid, 'BUG: bank does not have a GUID during migration to appdata')self.appdata.banks[#self.appdata.banks+1]={t=bank and 'g' or 'b',v=bank and bank.guid or msblsb,h=hash,src=b0+1,dst=b1+1,dstbus=1
}end
end
reaper.Undo_BeginBlock2(0)self:_write_appdata()for param=self.params.banks_start,self.params.banks_end do
self:set_param(param,0)end
reaper.Undo_EndBlock2(0, "Reaticulate: migrate track to new version (cannot be undone)", UNDO_STATE_FX)end
function rfx.Track:set_track_data(attr,value)self.appdata[attr]=value
self:queue_write_appdata()end
function rfx.Track:get_track_data(attr)if self.appdata then
return self.appdata[attr]
end
end
function rfx.Track:set_default_channel(channel)rfx.set_gmem_global_default_channel(channel)if self:valid()and channel~=self.appdata.defchan then
self:opcode(rfx.OPCODE_UPDATE_CURRENT_CCS)self.appdata.defchan=channel
self:queue_write_appdata()end
end
function rfx.Track:set_error(error)if self:valid()and error~=self.appdata.err then
self.appdata.err=error
self:queue_write_appdata()end
end
function rfx.Track:set_banks(banks)self.appdata.banks={}for _,bankinfo in ipairs(banks)do
local guid,srcchannel,dstchannel,dstbus,bankname=table.unpack(bankinfo)assert(guid, 'bug: attempting to set invalid bank')self.appdata.banks[#self.appdata.banks+1]={t=tonumber(guid) and 'b' or 'g',v=guid,src=srcchannel,dst=dstchannel,dstbus=dstbus,name=bankname,}end
return self:index_banks_by_channel_and_check_hash()end
function rfx.Track:get_banks(migrate)if not self.fx then
return function()end
end
local idx=1
local migrator=migrate and rfx.GUIDMigrator(self)return function()if self:valid()and self.appdata.banks and idx<=#self.appdata.banks then
local bankinfo=self.appdata.banks[idx]
idx=idx+1
if bankinfo and bankinfo.v then
local bank
if bankinfo.t=='g' then
bank=reabank.get_bank_by_guid(bankinfo.v)else
if not migrator then
migrator=rfx.GUIDMigrator(self)end
bank=migrator:migrate_bankinfo(bankinfo)end
return {idx=idx-1,bank=bank,guid=bank and bank.guid,type=bankinfo.t,srcchannel=bankinfo.src,dstchannel=bankinfo.dst,dstbus=bankinfo.dstbus,hash=bankinfo.h,userdata=bankinfo.ud,name=bankinfo.name,v=bankinfo.v,},migrator
else
log.warning('rfx: invalid bank found during get_banks(): %s', bankinfo and table.tostring(bankinfo))end
else
if migrator then
migrator:remap_bank_select()end
end
end
end
local function _get_bank_appdata_record(self,bank)if not self:valid()or not self.appdata.banks then
return nil
end
for n,bankdata in ipairs(self.appdata.banks)do
local v=bankdata.t=='g' and bank.guid or bank.msblsb
if tostring(bankdata.v)==v then
return bankdata
end
end
end
function rfx.Track:get_bank_userdata(bank,attr)local bankdata=_get_bank_appdata_record(self,bank)if bankdata and bankdata.ud then
return bankdata.ud[attr]
end
end
function rfx.Track:set_bank_userdata(bank,attr,value)local bankdata=_get_bank_appdata_record(self,bank)if not bankdata then
log.error('bank %s not found in appdata', bank.name)return false
end
if not bankdata.ud then
bankdata.ud={[attr]=value}else
bankdata.ud[attr]=value
end
self:queue_write_appdata()return true
end
function rfx.Track:get_banks_conflicts()if not self.fx then
return {}end
local programs={}local conflicts={}for channel=1,16 do
local first=nil
local banks=self.banks_by_channel[channel]
if banks then
for _,bank in ipairs(banks)do
local buses=0
for _,art in ipairs(bank.articulations)do
local idx=128*channel+art.program
local outputs=table.tostring(art:get_outputs())buses=buses|art.buses
local first=programs[idx]
if not first then
programs[idx]={bank=bank,art=art,outputs=outputs
}elseif first.outputs~=outputs then
local conflict=conflicts[bank]
if not conflict then
conflicts[bank]={source=first.bank,channels=1<<(channel-1),program=art.program
}else
conflict.channels=conflict.channels|(1<<(channel-1))end
end
end
bank.buses=buses
end
end
end
return conflicts
end
function rfx.Track:index_banks_by_channel_and_check_hash()if not self.fx then
return
end
self.banks_by_channel={}self.unknown_banks=nil
local resync=false
for b in self:get_banks()do
local bank=b.bank
if not bank then
if not self.unknown_banks then
self.unknown_banks={}end
self.unknown_banks[#self.unknown_banks+1]=b.guid
log.warning("rfx: instance refers to undefined bank %s", b.guid)else
log.debug("rfx: index bank=%s  hash=%s -> %s", bank.name, b.hash, bank:hash())bank.srcchannel=b.srcchannel
bank.dstchannel=b.dstchannel
bank.dstbus=b.dstbus
if b.srcchannel==17 then
for src=1,16 do
local banks_list=self.banks_by_channel[src]
if not banks_list then
banks_list={}self.banks_by_channel[src]=banks_list
end
banks_list[#banks_list+1]=bank
end
else
local banks_list=self.banks_by_channel[b.srcchannel]
if not banks_list then
banks_list={}self.banks_by_channel[b.srcchannel]=banks_list
end
banks_list[#banks_list+1]=bank
end
if b.hash~=bank:hash()then
resync=true
end
if not app.project_state.msblsb_by_guid[bank.guid] then
reabank.add_bank_to_project(bank)end
end
end
return resync
end
function rfx.Track:sync_custom_feedback_events()local msgs=self.appdata.track_select_feedback
if not msgs then
self:opcode(rfx.OPCODE_SET_CUSTOM_FEEDBACK_MIDI_BYTES,{})return {}end
local typemap={['bankselect'] = 0xb0,['cc'] = 0xb0,['program'] = 0xc0,['note'] = 0x90,['note-on'] = 0x90,['note-off'] = 0x80,}local errmsg
local bytes={}for _,msg in ipairs(msgs)do
local status=typemap[msg.type]
if msg.type=='raw' and msg.data1 then
for _, group in ipairs(msg.data1:split(' ', true)) do
if #group%2~=0 then
group='0' .. group
end
for byte in group:gmatch('..') do
local v=tonumber(byte,16)if not v then
errmsg=string.format("'%s' is not valid hex", byte)v=0
end
bytes[#bytes+1]=v
end
end
elseif status then
local msgbytes
local chan=msg.channel and msg.channel-1 or 0
status=status+chan
local d1=tonumber(msg.data1)local d2=tonumber(msg.data2)if not d1 or (msg.data2 and msg.data2 ~='' and not d2) then
errmsg=string.format('Value must be a number')end
if d1 and(d1<0 or d1>127)then
errmsg=string.format('%d is out of range (0-127)', d1)end
if d2 and(d2<0 or d2>127)then
return nil, string.format('%d is out of range (0-127)', d2)end
if msg.type=='bankselect' then
msgbytes={status,0,d1,status,32,d2 or 0}elseif msg.type=='program' then
msgbytes={status,d1}elseif msg.type=='note' then
msgbytes={status,d1,d2 or 127,0x80+chan,d1,0}elseif msg.type=='note-on' then
msgbytes={status,d1,d2 or 127}else
msgbytes={status,d1,d2 or 0}end
for i=1,#msgbytes do
bytes[#bytes+1]=msgbytes[i]
end
end
end
self:opcode(rfx.OPCODE_SET_CUSTOM_FEEDBACK_MIDI_BYTES,bytes)return bytes,errmsg
end
function rfx.Track:sync_banks_to_rfx()if not self.fx then
return
end
if not self:valid()or not self.appdata.banks then
return log.error("rfx: unexpectedly no track appdata or banks")end
assert(self.banks_by_channel, 'Called sync_banks_to_rfx() before calling index_banks_by_channel_and_check_hash()')log.time_start()reaper.Undo_BeginBlock2(0)rfx.push_state(self.track)self:opcode(rfx.OPCODE_CLEAR)self:sync_custom_feedback_events()for channel=1,16 do
local banks=self.banks_by_channel[channel]
if banks then
for _,bank in ipairs(banks)do
bank:realize()local param1=(channel-1)|(0<<4)local msb,lsb=bank:get_current_msb_lsb()self:opcode(rfx.OPCODE_NEW_BANK,{param1,msb,lsb})for _,cc in ipairs(bank:get_chase_cc_list())do
self:opcode(rfx.OPCODE_SET_BANK_CHASE_CC,{cc})end
for _,art in ipairs(bank.articulations)do
local version=2
local group=art.group-1
local outputs=art:get_outputs()local param1=(channel-1)|(version<<4)self:opcode(rfx.OPCODE_NEW_ARTICULATION,{param1,art.program,group,art.flags,art.off or bank.off or 128,0})if art:has_transforms()then
local transforms=art:get_transforms()self:opcode(rfx.OPCODE_ADD_ARTICULATION_EXTENSION,{0,(transforms[1]+128)|(math.floor(transforms[2]*100)<<8),transforms[3]|(transforms[4]<<8),transforms[5]|(transforms[6]<<8)})end
for _,output in ipairs(outputs)do
local outchannel=output.channel or bank.dstchannel
local outbus=output.bus or bank.dstbus or 1
local param1=tonumber(output.args[1] or 0)local param2=tonumber(output.args[2] or 0)if not output.route then
param1=param1|0x80
end
if outchannel==17 then
outchannel=channel
elseif outchannel==0 then
param2=param2|0x80
param1=param1|0x80
outchannel=1
outbus=1
end
if output.type=='pitch' then
param1=math.max(-8192,math.min(8191,param1))+8192
param2=(param1>>7)&0x7f
param1=param1&0x7f
end
local haschannel=output.channel or bank.dstchannel~=17
local hasbus=output.bus or bank.dstbus~=1
local typechannel=(output_type_to_rfx_param[output.type] or 0)|((outchannel-1)<<4)|((outbus-1)<<8)|((haschannel and 1 or 0)<<12)|((hasbus and 1 or 0)<<13)self:opcode(rfx.OPCODE_ADD_OUTPUT_EVENT,{typechannel,param1,param2})if output.filter_program then
self:opcode(rfx.OPCODE_ADD_OUTPUT_EVENT_EXTENSION,{0,output.filter_program|0x80})end
end
end
end
end
end
self:opcode(rfx.OPCODE_FINALIZE_ARTICULATIONS)for b in self:get_banks()do
self.appdata.banks[b.idx].h=b.bank and b.bank:hash()or nil
end
self:_write_appdata()rfx.pop_state()reaper.Undo_EndBlock2(0, "Reaticulate: update track banks (cannot be undone)", UNDO_STATE_FX)log.info("rfx: sync articulations done")log.time_end()end
function rfx.Track:sync_banks_if_hash_changed()if not self.track then
return false
end
local changed=false
for b in self:get_banks()do
if b.bank and b.hash~=b.bank:hash()then
changed=true
break
end
end
if changed then
if not self.banks_by_channel then
self:index_banks_by_channel_and_check_hash()end
self:sync_banks_to_rfx()if self==rfx.current then
rfx.onhashchange()end
end
end
function rfx.Track:clear_channel_program(channel,group)self:opcode(rfx.OPCODE_CLEAR_ARTICULATION,{channel-1,group-1})end
function rfx.Track:activate_articulation(channel,program,flags)self:opcode(rfx.OPCODE_ACTIVATE_ARTICULATION,{channel,program,flags or 0})end
function rfx.Track:subscribe(subscription,track,fx)self:opcode(rfx.OPCODE_SUBSCRIBE,{subscription})end
function rfx.Track:get_item_userdata(item)local ok, data=reaper.GetSetMediaItemInfo_String(item, 'P_EXT:reaticulate', '', false)if not ok then
return {}end
local ok,decoded=pcall(json.decode,data)return ok and type(decoded)=='table' and decoded or {}end
function rfx.Track:set_item_userdata(item,itemdata)local encoded=json.encode(itemdata)reaper.GetSetMediaItemInfo_String(item, 'P_EXT:reaticulate', encoded, true)end
function rfx.Track:set_item_userdata_key(item,key,value)local itemdata=self:get_item_userdata(item)itemdata[key]=value
self:set_item_userdata(item,itemdata)end
function rfx.Track:opcode(opcode,args)return rfx.opcode(opcode,args,self.track,self.fx,self.gmem_index,self.params.opcode)end
function rfx.Track:opcode_flush()if self.track and self.fx then
rfx.opcode_flush(self.track,self.fx,self.gmem_index,self.params.opcode)end
end
function rfx.Track:queue_write_appdata()rfx._queue_commit(self.track,nil,self.appdata,self.gmem_index)end
function rfx.Track:_write_appdata(appdata)rfx._write_appdata(self.track,appdata or self.appdata)end
function rfx.Track:_read_appdata()if not self.track then
return nil
end
local r, data=reaper.GetSetMediaTrackInfo_String(self.track, 'P_EXT:reaticulate', '', false)if r then
local version=data:sub(1,1)if version=='2' then
log.debug('rfx: deserialize new appdata ver=%s: %s', version, data)local ok,decoded=pcall(json.decode,data:sub(2))if ok then
return decoded
end
else
log.error("rfx: could not understand stored Reaticulate FX data (serialization version %s)", version)return nil
end
end
if not self.fx then
return nil
end
local t0=reaper.time_precise()local offset=self.gmem_index+rfx.GMEM_IIDX_APP_DATA
local ok
local appdata=nil
local version=reaper.gmem_read(offset+0)log.debug("rfx: read appdata version=%s from offset=%s", version, offset)if version==1 then
local strlen=reaper.gmem_read(offset+1)local bytes={}for i=1,strlen,3 do
local packed=reaper.gmem_read(offset+3+(i-1)/3)bytes[#bytes+1]=string.char(packed&0xff)bytes[#bytes+1]=string.char((packed>>8)&0xff)bytes[#bytes+1]=string.char((packed>>16)&0xff)end
local str=table.concat(bytes, '', 1, strlen)ok,appdata=pcall(binser.deserialize,str)local t1=reaper.time_precise()if not ok then
log.error("rfx: deserialization of %s bytes failed: %s", #str, appdata)return nil
end
log.debug("rfx: deserialize ver=%s from %s took: %s", version, offset, t1-t0, version)log.logf(log.DEBUG2, "rfx: resulting data: sz=%s   %s\n",function()return strlen,table.tostring(appdata)end
)log.info('rfx: migrating appdata to native track extension data')self:_write_appdata(appdata[1])reaper.gmem_write(offset+1,0)reaper.gmem_write(offset+2,0)self:opcode(rfx.OPCODE_SET_APPDATA)return appdata[1]
else
log.error("rfx: could not understand rfx stored data (serialization version %s)", version)end
return appdata
end
function rfx.Track:get_param(param)if self.track and self.fx then
local r,_,_=reaper.TrackFX_GetParam(self.track,self.fx,param)if r>=0 then
return math.floor(r)&0xffffffff
end
end
return nil
end
function rfx.Track:set_param(param,value)if self.track and self.fx then
return reaper.TrackFX_SetParam(self.track,self.fx,param,value or 0)end
return false
end
function rfx.Track:get_data(param)local r=self:get_param(param)if r then
local b0,b1,b2=r&0xff,(r&0xff00)>>8,(r&0xff0000)>>16
local b3=(r&0x7f000000)>>24
return b0,b1,b2,b3
else
return nil,nil,nil,nil
end
end
return rfx
end)()

local rfx=__mod_rfx
local reabank=__mod_reabank
__mod_articons=(function()
local rtk=rtk
local articons={}local remap={['tremolo-measured'] = 'tremolo-measured-sixteenth',['tremolo-150'] = 'tremolo-measured-sixteenth',['tremolo-180'] = 'tremolo-measured-sixteenth',['tremolo-150-con-sord'] = 'tremolo-measured-sixteenth-con-sord',['tremolo-180-con-sord'] = 'tremolo-measured-sixteenth-con-sord',['marcato'] = 'marcato-half',['riccochet'] = 'ricochet',['rip-downward'] = 'plop',['staccato-overblown'] = 'staccato-stopped',['vibrato-rachmaninoff'] = 'vibrato-molto',['legato-slurred'] = 'note-tied',['phrase-tremolo'] = 'phrase-multitongued',['phrase-tremolo-cresc'] = 'phrase-multitongued-cresc',['esp-half'] = 'note-half',['cresc-m-half'] = 'cresc-mf-half',['pizz-a'] = 'pizz',['pizz-b'] = 'pizz',['frozen'] = 'note-whole',['frozen-eighth'] = 'note-eighth',['frozen-half'] = 'note-half',['col-legno-loose'] = 'col-legno',['no-rosin'] = 'note-whole-feathered',}function articons.init()local img=rtk.ImagePack()local strips={}for _,density in ipairs{1,1.5,2} do
for _,row in ipairs(articons.rows)do
strips[#strips+1]={w=32*density,h=28*density,names=row,density=density,}end
end
img:add{src='articulations.png', style='light', strips=strips}articons.img=img
end
function articons.get(name,dark,default)local style=dark and 'dark' or 'light'local icon=articons.img:get(remap[name] or name or default,style)if not icon and default then
icon=articons.img:get(default,style)end
return icon
end
function articons.get_for_bg(name,color)local luma=rtk.color.luma(color)return articons.get(name,luma>0.6)end
articons.rows={{'accented-half','accented-quarter','acciaccatura-quarter','alt-circle','blend','bow-down','bow-up','col-legno','col-legno-whole','con-sord','con-sord-blend','con-sord-bow-down','con-sord-bow-up',},{'con-sord-sul-pont','con-sord-sul-pont-bow-up','cresc-f-half','cresc-half','cresc-m-half','cresc-mf-half','cresc-mp-half','cresc-p-half','cresc-quarter','crescendo','cuivre','dblstop-5th','dblstop-5th-eighth',},{'decrescendo','fall','fanfare','flautando','flautando-con-sord','flautando-con-sord-eighth','fx','ghost-eighth','harmonics','harmonics-natural','harmonics-natural-eighth','harp-pdlt2','legato',},{'legato-blend-generic','legato-bowed','legato-bowed2','legato-con-sord','legato-fast','legato-flautando','legato-gliss','legato-portamento','legato-portamento-con-sord','legato-portamento-flautando','legato-runs','legato-slow','legato-slow-blend',},{'note-tied','legato-sul-c','legato-sul-g','legato-sul-pont','legato-tremolo','legato-vibrato','list','marcato-half','marcato-quarter','note-acciaccatura','light','note-eighth','note-half',},{'note-quarter','note-sixteenth','note-whole','phrase2','pizz','pizz-bartok','pizz-con-sord','pizz-mix','pizz-sul-pont','rest-quarter','ricochet','rip','plop',},{'run-major','run-minor','sfz','spiccato','spiccato-breath','spiccato-brushed','spiccato-brushed-con-sord','spiccato-brushed-con-sord-sul-pont','spiccato-feathered','staccatissimo-stopped','staccato','staccato-breath','staccato-con-sord',},{'staccato-dig','staccato-harmonics','staccato-harmonics-half','staccato-stopped','staccato-sfz','stopped','sul-c','sul-g','sul-pont','sul-tasto','tenuto-eighth','tenuto-half','tenuto-quarter',},{'tremolo','tremolo-con-sord','tremolo-con-sord-sul-pont','tremolo-sul-pont','tremolo-ghost','tremolo-harmonics','tremolo-fingered','tremolo-measured-eighth','tremolo-measured-sixteenth','tremolo-measured-eighth-con-sord','tremolo-measured-sixteenth-con-sord','trill','trill-maj2',},{'trill-maj3','trill-min2','trill-min3','trill-perf4','vibrato','vibrato-con-sord','vibrato-molto','portato','scoop','bend-up','bend-down','fortepiano','multitongued',},{'alt-gypsy','alt-gypsy-eighth','alt-gypsy-harmonics','alt-tremolo-gypsy-harmonics','alt-wave','alt-wave-double','alt-wave-double-stopped','alt-wave-double-tr','alt-x','harp-pdlt','phrase','phrase-multitongued','phrase-multitongued-cresc',},{'sul-tasto-super','sul-tasto-super-eighth','tremolo-harmonics-a','tremolo-harmonics-b','tremolo-slurred',},}return articons
end)()

local articons=__mod_articons
__mod_feedback=(function()
local rfx=__mod_rfx
local rtk=rtk
local log=rtk.log
local feedback={SYNC_CC=1,SYNC_ARTICULATIONS=2,SYNC_CHANNEL=4,SYNC_TRACK=8,SYNC_ALL=1|2|4|8,track=nil,track_guid=nil
}local BUS_TRANSLATOR_MAGIC=0x42424242
local BUS_TRANSLATOR_FX_SCRIPT='Feedback Translate.jsfx'local BUS_TRANSLATOR_FX_DESC='Bus Translator for MIDI Feedback (Reaticulate)'function feedback.is_enabled()return(app.config.cc_feedback_device or-1)>=0 and app.config.cc_feedback_active
end
function feedback.ontrackchange(last,cur)if not feedback.is_enabled()then
return
end
if last then
feedback._set_track_enabled(last,0)end
if cur and rfx.current.fx then
local input=reaper.GetMediaTrackInfo_Value(cur, "I_RECINPUT")if input and input&4096~=0 then
feedback._set_track_enabled(cur,1)if feedback.add_feedback_send(cur)then
feedback.scroll_mixer(cur)local cycles=5
local function sync()if cycles==0 then
feedback.sync(cur)else
cycles=cycles-1
rtk.defer(sync)end
end
rtk.defer(sync)else
feedback._sync(feedback.SYNC_ALL)end
end
end
end
function feedback.scroll_mixer(track)local scroll_mixer=reaper.GetToggleCommandStateEx(0,40221)if scroll_mixer and track then
local function scroll()reaper.SetMixerScroll(track)end
scroll()rtk.defer(scroll)end
end
function feedback.get_feedback_send(track)local feedback_track=feedback.get_feedback_track()if feedback_track then
for idx=0,reaper.GetTrackNumSends(track,0)-1 do
local target=reaper.BR_GetMediaTrackSendInfo_Track(track,0,idx,1)if target==feedback_track then
return idx
end
end
end
return nil
end
function feedback.add_feedback_send(track)local feedback_track=feedback.ensure_feedback_track()if feedback.get_feedback_send(track)then
return false
else
local idx=reaper.CreateTrackSend(track,feedback_track)reaper.SetTrackSendInfo_Value(track, 0, idx, 'I_SRCCHAN', -1)reaper.SetTrackSendInfo_Value(track, 0, idx, 'I_MIDIFLAGS', 1 << 18)return true
end
end
function feedback._set_track_enabled(track,enabled)local device=app.config.cc_feedback_device-1
local bus=15
if app.config.cc_feedback_device<0 then
enabled=0
end
rfx.opcode_on_track(track,rfx.OPCODE_SET_CC_FEEDBACK_ENABLED,{enabled,bus})end
function feedback.get_feedback_track_fx_idx(track)local fx=reaper.TrackFX_GetByName(track,BUS_TRANSLATOR_FX_DESC,false)if fx==-1 then
fx=reaper.TrackFX_GetByName(track,BUS_TRANSLATOR_FX_SCRIPT,false)end
return fx
end
function feedback.get_feedback_track()if feedback.track and reaper.ValidatePtr2(0, feedback.track, "MediaTrack*") and
reaper.GetTrackGUID(feedback.track)==feedback.track_guid then
return feedback.track
end
for i=0,reaper.CountTracks(0)-1 do
local track=reaper.GetTrack(0,i)local fx=feedback.get_feedback_track_fx_idx(track)if fx>=0 then
local val,_,_=reaper.TrackFX_GetParam(track,fx,3)if val==BUS_TRANSLATOR_MAGIC then
feedback.track=track
feedback.track_guid=reaper.GetTrackGUID(track)return track
end
end
end
return nil
end
function feedback.create_feedback_track()log.info('creating track for MIDI feedback')reaper.PreventUIRefresh(1)local idx=reaper.CountTracks(0)reaper.InsertTrackAtIndex(idx,false)feedback.track=reaper.GetTrack(0,idx)reaper.SetMediaTrackInfo_Value(feedback.track, 'B_SHOWINTCP', 0)reaper.SetMediaTrackInfo_Value(feedback.track, 'B_SHOWINMIXER', 0)feedback.track_guid=reaper.GetTrackGUID(feedback.track)reaper.GetSetMediaTrackInfo_String(feedback.track, 'P_NAME', "MIDI Feedback (Reaticulate)", true)local fx=reaper.TrackFX_AddByName(feedback.track,BUS_TRANSLATOR_FX_SCRIPT,0,1)reaper.TrackFX_Show(feedback.track,fx,2)feedback.update_feedback_track_settings()feedback.scroll_mixer(app.track)reaper.PreventUIRefresh(-1)return feedback.track
end
function feedback.destroy_feedback_track()local feedback_track=feedback.get_feedback_track()if feedback_track then
for idx=0,reaper.CountTracks(0)-1 do
local track=reaper.GetTrack(0,idx)if track then
local send=feedback.get_feedback_send(track)if send then
reaper.RemoveTrackSend(track,0,send)end
end
end
reaper.DeleteTrack(feedback_track)feedback.track=nil
end
end
function feedback.update_feedback_track_settings(dosync)local feedback_track=feedback.get_feedback_track()if feedback_track then
reaper.SetMediaTrackInfo_Value(feedback_track, "I_MIDIHWOUT", app.config.cc_feedback_device << 5)local fx=feedback.get_feedback_track_fx_idx(feedback_track)if fx==-1 then
log.error("feedback: CC feedback is enabled but Bus Translator FX not found")else
reaper.Undo_BeginBlock()rfx.push_state(feedback_track)reaper.TrackFX_SetParam(feedback_track,fx,0,app.config.cc_feedback_active and 1 or 0)reaper.TrackFX_SetParam(feedback_track,fx,1,15)reaper.TrackFX_SetParam(feedback_track,fx,2,app.config.cc_feedback_bus-1)reaper.TrackFX_SetParam(feedback_track,fx,3,BUS_TRANSLATOR_MAGIC)local articulation_cc=0
if app.config.cc_feedback_articulations==2 then
articulation_cc=app.config.cc_feedback_articulations_cc or 0
end
reaper.TrackFX_SetParam(feedback_track,fx,4,articulation_cc)rfx.pop_state()reaper.Undo_EndBlock("Reaticulate: update feedback track settings", UNDO_STATE_FX)if dosync then
feedback.ontrackchange(nil,app.track)end
end
end
end
function feedback.ensure_feedback_track()local feedback_track=feedback.get_feedback_track()if feedback_track then
return feedback_track
else
return feedback.create_feedback_track()end
end
function feedback._sync(what)rfx.current:opcode(rfx.OPCODE_SYNC_TO_FEEDBACK_CONTROLLER,{what})end
function feedback.sync(track,what)if not feedback.is_enabled()or not track or not rfx.current.fx then
return
end
feedback._sync(what or feedback.SYNC_ALL)end
function feedback.set_active(active)app.config.cc_feedback_active=active
app:queue_save_config()feedback.update_feedback_track_settings()end
return feedback
end)()

local feedback=__mod_feedback
local json=__mod_lib_json
local log=rtk.log
App=rtk.class('App', BaseApp)App.static.SAVE_PROJECT_STATE=1
App.static.REFRESH_BANKS=2
App.static.CLEAN_UNUSED_BANKS=4
App.static.REPARSE_REABANK_FILE=8
App.static.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK=16
App.static.FORCE_RECOGNIZE_BANKS_PROJECT=32
App.static.REFRESH_BANKS_ACTIONS=2|4|8|32
function App:initialize(basedir,t0,t1)self.config={cc_feedback_device=-1,cc_feedback_bus=1,cc_feedback_articulations=1,cc_feedback_articulations_cc=0,cc_feedback_active=true,autostart=0,art_colors=nil,track_selection_follows_midi_editor=true,track_selection_follows_fx_focus=false,art_insert_at_selected_notes=true,single_floating_instrument_fx_window=false,keyboard_focus_follows_mouse=false,default_channel_behavior=nil,chase_ccs=nil,}self.config_map_to_script={track_selection_follows_midi_editor={0, 'Reaticulate_Toggle track selection follows MIDI editor target item.lua'},track_selection_follows_fx_focus={0, 'Reaticulate_Toggle track selection follows focused FX window.lua'},single_floating_instrument_fx_window={0, 'Reaticulate_Toggle single floating instrument FX window for selected track.lua'},keyboard_focus_follows_mouse={0, 'Reaticulate_Toggle keyboard focus follows mouse.lua'},art_insert_at_selected_notes={0, 'Reaticulate_Toggle insert articulations based on selected notes when MIDI editor is open.lua'},}self.known_focus_classes={REAPERmidieditorwnd='midi_editor',REAPERTCPDisplay='tcp',REAPERTrackListWindow='arrange',REAPERMCPDisplay='hwnd',Lua_LICE_gfx_standalone='hwnd',eelscript_gfx='hwnd',['#32770'] = 'hwnd',}if BaseApp.initialize(self, 'reaticulate', 'Reaticulate', basedir) == false then
return
end
self.track=nil
self.project_change_cookie=nil
self.project_dirty=nil
self.project_state=nil
self.queued_actions=0
self.active_projects_by_cookie={}self.last_track=nil
self.default_channel=1
self.midi_hwnd=nil
self.midi_editor_take=nil
self.midi_editor_track=nil
self.midi_linked=false
self.active_articulations={}self.pending_articulations={}self.last_activated_articulation=nil
self.last_activation_timestamp=nil
self.last_focused_hwnd=nil
self.last_focus_time=nil
self.saved_focus_window=nil
self.refocus_target_time=nil
self.reaper_supports_track_data_reload=rtk.check_reaper_version(6,46)articons.init()rfx.init()reabank.init()if not self.config.art_colors then
self.config.art_colors={}for color,value in pairs(reabank.default_colors)do
if reabank.colors[color] and reabank.colors[color]~=value then
self.config.art_colors[color]=value
end
end
end
self:add_screen('installer', 'screens.installer')self:add_screen('banklist', 'screens.banklist')self:add_screen('trackcfg', 'screens.trackcfg')self:add_screen('settings', 'screens.settings')self:replace_screen('banklist')self:set_default_channel(1)self:run()local now=reaper.time_precise()log.debug('app: initialization took: %s (import=%s build=%s)', now-t0, t1-t0, now-t1)end
function App:get_config()local cfg=BaseApp.get_config(self)if not cfg.default_channel_behavior then
local ok, editor=reaper.get_config_var_string('midieditor')editor=tonumber(editor)or 1
if editor&1~=0 or editor&2~=0 then
cfg.default_channel_behavior=2
else
cfg.default_channel_behavior=3
end
end
return cfg
end
function App:_run_queued_actions()local flags=self.queued_actions
if flags&App.SAVE_PROJECT_STATE~=0 then
local state=json.encode(self.project_state)reaper.SetProjExtState(0, 'reaticulate', 'state', state)log.info('app: saved project state (%s bytes)', #state)log.debug('app: current project state: %s', state)end
if flags&App.REFRESH_BANKS_ACTIONS~=0 then
self:refresh_banks(flags)elseif flags&App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK~=0 then
if self:has_arrange_view_pc_names()or self.midi_hwnd then
self:force_recognize_bank_change_one_track(rfx.current.track,true)end
end
self.queued_actions=0
end
function App:queue(flags)if self.queued_actions==0 then
rtk.defer(self._run_queued_actions,self)end
self.queued_actions=self.queued_actions|(flags or 0)end
function App:log_msblsb_mapping()local text={}for guid,msblsb in pairs(self.project_state.msblsb_by_guid)do
local bank=reabank.get_bank_by_guid(guid)text[#text+1]=string.format('       %s -> %s/%s (%s)',guid,(msblsb>>8)&0xff,msblsb&0xff,bank and bank.name or 'UNKNOWN!')end
log.debug('MSB/LSB assignment:\n%s', table.concat(text, '\n'))end
function App:onprojectchange(opened)local r, data=reaper.GetProjExtState(0, 'reaticulate', 'state')log.info('app: project changed (opened=%s cookie=%s)', opened, self.project_change_cookie)log.debug('app: loaded project state: %s', data)self.project_state={}if r~=0 then
local ok,decoded=pcall(json.decode,data)if ok then
self.project_state=decoded
else
log.error('failed to restore Reaticulate project state: %s', decoded)end
end
local flags=App.REFRESH_BANKS
reabank.onprojectchange()if r==0 then
log.info('app: beginning project migration to GUID')self:migrate_project_to_guid()flags=flags|App.SAVE_PROJECT_STATE
end
if opened then
flags=flags|App.FORCE_RECOGNIZE_BANKS_PROJECT|App.CLEAN_UNUSED_BANKS
end
self:queue(flags)end
function App:ontrackchange(last,cur)last=reaper.ValidatePtr2(0, last, 'MediaTrack*') and last or nil
cur=reaper.ValidatePtr2(0, cur, 'MediaTrack*') and cur or nil
local lastn,curn
if last then
lastn=reaper.GetMediaTrackInfo_Value(last, 'IP_TRACKNUMBER')end
if cur then
curn=reaper.GetMediaTrackInfo_Value(cur, 'IP_TRACKNUMBER')end
log.info('app: track change: %s -> %s', lastn, curn)reaper.PreventUIRefresh(1)self.screens.banklist.filter_entry:onchange()if cur then
reaper.CSurf_OnTrackSelection(cur)if self.config.single_floating_instrument_fx_window then
self:do_single_floating_fx()end
end
self:check_banks_for_errors()reaper.PreventUIRefresh(-1)end
local function _check_track_for_midi_events(track)for itemidx=0,reaper.CountTrackMediaItems(track)-1 do
local item=reaper.GetTrackMediaItem(track,itemidx)for takeidx=0,reaper.CountTakes(item)-1 do
local take=reaper.GetTake(item,takeidx)local r=reaper.MIDI_GetCC(take,0)if r then
return true
end
end
end
return false
end
function App:migrate_project_to_guid()self.project_state.gc_ok=true
log.time_start()local old=self.project_state.msblsb_by_guid
self.project_state.msblsb_by_guid={}for idx,rfxtrack in rfx.get_tracks(0,true)do
if rfxtrack.appdata==nil then
self.project_state.gc_ok=false
else
for b,migrator in rfxtrack:get_banks(true)do
if b.type=='g' and b.bank then
local msb,lsb
local last=old[b.guid]
if last then
msb,lsb=last and last>>8,last and last&0xff
end
migrator:add_bank_to_project(b.bank,msb,lsb)end
if not b.bank then
if b.type=='g' and b.guid then
self.project_state.msblsb_by_guid[b.guid]=old[b.guid]
log.warning('app: bank GUID not found: %s', b.guid)else
log.warning('app: legacy bank MSB/LSB not found: %s', b.v)end
end
end
end
end
log.info('app: done full track scrub')log.time_end()return true
end
function App:clean_unused_project_banks()self:migrate_project_to_guid()end
local function get_instrument_hwnd_for_track(track)if track then
local vsti=reaper.TrackFX_GetInstrument(track)if vsti>=0 then
return reaper.TrackFX_GetFloatingWindow(track,vsti),vsti
end
end
return nil,nil
end
function App:do_single_floating_fx()if not rtk.has_js_reascript_api then
return
end
log.time_start()local cur=self.track
local lastfx=nil
local tracks={}local hidden={}for i=0,reaper.CountTracks(0)-1 do
local track=reaper.GetTrack(0,i)local hwnd,fx=get_instrument_hwnd_for_track(track)if hwnd then
if reaper.JS_Window_IsVisible(hwnd)then
tracks[#tracks+1]={track,fx,hwnd}if track==self.last_track then
lastfx=tracks[#tracks]
end
else
hidden[#hidden+1]={track,fx}end
end
end
if #tracks>0 and self.config.single_floating_instrument_fx_window then
if not lastfx then
lastfx=tracks[1]
end
if #tracks>1 then
for i,fxinfo in ipairs(tracks)do
if fxinfo[1]~=lastfx[1] and fxinfo[1]~=cur then
reaper.TrackFX_Show(fxinfo[1],fxinfo[2],2)end
end
end
local last_track,last_fx,last_hwnd=table.unpack(lastfx)local cur_hwnd,cur_fx=get_instrument_hwnd_for_track(cur)if not cur_hwnd and cur_fx then
reaper.TrackFX_Show(cur,cur_fx,3)cur_hwnd,_=get_instrument_hwnd_for_track(cur)end
if cur_hwnd and last_hwnd and cur_hwnd~=last_hwnd then
local _,target_x,target_y,_,_=reaper.JS_Window_GetRect(last_hwnd)reaper.JS_Window_Move(cur_hwnd,target_x,target_y)reaper.JS_Window_Show(cur_hwnd, "SHOW")reaper.JS_Window_SetZOrder(cur_hwnd, "INSERT_AFTER", last_hwnd)rtk.defer(reaper.JS_Window_Show, last_hwnd, "HIDE")end
self:refocus()end
if(#tracks==0 and #hidden>0)or not self.config.single_floating_instrument_fx_window then
rtk.defer(function()for i,fxinfo in ipairs(hidden)do
local _, name=reaper.GetTrackName(fxinfo[1], "")reaper.TrackFX_Show(fxinfo[1],fxinfo[2],2)end
end)end
log.debug("app: done manging fx windows")log.time_end()end
function App:get_take_at_position(track,pos)if not track then
return
end
for idx=0,reaper.CountTrackMediaItems(track)-1 do
local item=reaper.GetTrackMediaItem(track,idx)local startpos=reaper.GetMediaItemInfo_Value(item, 'D_POSITION')local endpos=startpos + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')if pos>=startpos and pos<endpos then
return item,reaper.GetActiveTake(item)end
end
end
local function _delete_program_events_at_ppq(take,channel,idx,max,startppq,endppq)while idx>=0 do
local rv,selected,muted,evtppq,command,evtchan,msg2,msg3=reaper.MIDI_GetCC(take,idx)if evtppq~=startppq then
break
end
idx=idx-1
end
local lastmsb,lastlsb,msb,lsb,program=nil,nil,nil,nil,nil
idx=idx+1
while idx<max do
local rv,selected,muted,evtppq,command,evtchan,msg2,msg3=reaper.MIDI_GetCC(take,idx)if evtppq<startppq or evtppq>endppq then
break
end
if command==0xb0 and msg2==0 and channel==evtchan then
lastmsb=msg3
reaper.MIDI_DeleteCC(take,idx)elseif command==0xb0 and msg2==32 and channel==evtchan then
lastlsb=msg3
reaper.MIDI_DeleteCC(take,idx)elseif command==0xc0 and channel==evtchan then
msb,lsb,program=lastmsb,lastlsb,msg2
reaper.MIDI_DeleteCC(take,idx)else
idx=idx+1
end
end
return msb,lsb,program
end
local function _get_cc_idx_at_ppq(take,ppq)local _,_,n_events,_=reaper.MIDI_CountEvts(take)local skip=math.floor(n_events/2)local idx=skip
local previdx,prevppq=nil,nil
local nextidx,nextppq=nil,nil
while idx>0 and idx<n_events and skip>0.5 do
local rv,_,_,evtppq,_,evtchan,_,_=reaper.MIDI_GetCC(take,idx)local delta=math.abs(evtppq-ppq)if delta<1 then
return true,previdx,prevppq,idx,evtppq,n_events
end
skip=skip/2
if evtppq>ppq then
nextidx,nextppq=idx,evtppq
idx=idx-math.ceil(skip)elseif evtppq<ppq then
previdx,prevppq=idx,evtppq
idx=idx+math.ceil(skip)end
end
return false,previdx,prevppq,nextidx,nextppq,n_events
end
local function _delete_program_changes(take,channel,startppq,endppq)local found,_,_,idx,ppq,n_events=_get_cc_idx_at_ppq(take,startppq)if not ppq or ppq<startppq or ppq>endppq then
return
end
local msb,lsb,program=_delete_program_events_at_ppq(take,channel,idx,n_events,ppq,endppq)return msb,lsb,program
end
local function _insert_program_change(take,ppq,channel,msb,lsb,program,overwrite)local found,_,_,idx,foundppq,n_events=_get_cc_idx_at_ppq(take,ppq)if found then
if not overwrite then
log.exception('TODO: fix this bug')return
end
_delete_program_events_at_ppq(take,channel,idx,n_events,foundppq,foundppq)end
reaper.MIDI_InsertCC(take,false,false,ppq,0xb0,channel,0,msb)reaper.MIDI_InsertCC(take,false,false,ppq,0xb0,channel,32,lsb)reaper.MIDI_InsertCC(take,false,false,ppq,0xc0,channel,program,0)end
local function _get_insertion_points_by_selected_notes(take,program)local insert_ppqs={}local delete_ppqs={}local offset=0
local idx=-1
local selranges={}local last_notes={}local paranoia_counter=0
local _,n_notes,_,_=reaper.MIDI_CountEvts(take)while paranoia_counter<=n_notes do
local nextidx=reaper.MIDI_EnumSelNotes(take,idx)if nextidx==-1 then
break
end
local r,_,_,noteppq,noteppqend,notechan,_,_=reaper.MIDI_GetNote(take,nextidx)if not r then
break
end
last_notes[notechan]={nextidx,noteppq}if idx~=-1 then
for unselidx=idx+1,nextidx-1 do
local r,_,_,_,_,unselchan,_,_=reaper.MIDI_GetNote(take,unselidx)if not r then
break
end
local selinfo=selranges[unselchan]
if selinfo and selinfo[3] then
delete_ppqs[#delete_ppqs+1]={take,selinfo[2],selinfo[4],unselchan}end
selranges[unselchan]=nil
end
end
if not selranges[notechan] then
insert_ppqs[#insert_ppqs+1]={take,math.ceil(noteppq-offset),notechan,program}selranges[notechan]={nextidx,noteppq-offset,nil,nil}else
selranges[notechan][3]=nextidx
selranges[notechan][4]=noteppq-offset
end
idx=nextidx
paranoia_counter=paranoia_counter+1
end
for ch,selinfo in pairs(selranges)do
if selinfo[3] then
delete_ppqs[#delete_ppqs+1]={take,selinfo[2],selinfo[4],ch}end
end
return insert_ppqs,delete_ppqs
end
function App:_insert_articulation(rfxtrack,bank,program,channel,take,allow_create_item,insert_selected_notes,insert_edit_cursor)local track=rfxtrack.track
local insert_ppqs,delete_ppqs
if take and reaper.ValidatePtr(take, 'MediaItem_Take*') and insert_selected_notes ~= false then
insert_ppqs,delete_ppqs=_get_insertion_points_by_selected_notes(take,program)end
local msb,lsb
if bank then
msb,lsb=bank:get_current_msb_lsb()else
for b in rfxtrack:get_banks()do
if(b.srcchannel==17 or b.srcchannel==channel+1)and
b.bank and b.bank:get_articulation_by_program(program)then
msb,lsb=b.bank:get_current_msb_lsb()break
end
end
end
if not msb or not lsb then
local n=reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')log.warning('app: program %d could not be found on track %d for insertion', program, n)return false
end
if(not insert_ppqs or #insert_ppqs==0)and insert_edit_cursor~=false then
local cursor=reaper.GetCursorPositionEx(0)local _,candidate=self:get_take_at_position(track,cursor)if candidate and(not take or candidate==take)then
take=candidate
local ppq=reaper.MIDI_GetPPQPosFromProjTime(take,cursor)insert_ppqs={{take,ppq,nil,program}}elseif allow_create_item~=false then
local item=reaper.CreateNewMIDIItemInProj(track,cursor,cursor+1,false)reaper.SetMediaItemInfo_Value(item, 'B_LOOPSRC', 0)take=reaper.GetActiveTake(item)local ppq=reaper.MIDI_GetPPQPosFromProjTime(take,cursor)insert_ppqs={{take,ppq,nil,program}}else
return
end
end
if delete_ppqs then
for _,range in ipairs(delete_ppqs)do
local take,startppq,endppq,delchan=table.unpack(range)_delete_program_changes(take,delchan,startppq,endppq)end
end
local takes={}for _,ppqchan in ipairs(insert_ppqs)do
local take,ppq,chan,program=table.unpack(ppqchan)_insert_program_change(take,ppq,chan or channel,msb,lsb,program,true)takes[take]=1
end
for take,_ in pairs(takes)do
local item=reaper.GetMediaItemTake_Item(take)local track=reaper.GetMediaItem_Track(item)reaper.UpdateItemInProject(item)reaper.MarkTrackItemsDirty(track,item)end
rfxtrack:activate_articulation(channel,program,1)return insert_ppqs and #insert_ppqs>0
end
function App:_stuff_articulation_pc(art,srcchannel)local bank=art:get_bank()local msb,lsb=bank:get_current_msb_lsb()reaper.StuffMIDIMessage(0,0xb0+srcchannel,0,msb)reaper.StuffMIDIMessage(0,0xb0+srcchannel,0x20,lsb)reaper.StuffMIDIMessage(0,0xc0+srcchannel,art.program,0)end
function App:activate_articulation(art,refocus,force_insert,channel,insert_at_cursor)if not art or art.program<0 then
return false
end
log.time_start()if refocus then
self:refocus_delayed(force_insert and 0 or 0.5)end
local bank=art:get_bank()local srcchannel=bank:get_src_channel(channel or app.default_channel)-1
local recording=reaper.GetAllProjectPlayStates(0)&4~=0
if recording then
self:_stuff_articulation_pc(art,srcchannel)art.button.start_insert_animation()return
end
if not self.config.art_insert_at_selected_notes then
insert_at_cursor=true
end
if force_insert==nil or force_insert==0 then
local delta=reaper.time_precise()-(self.last_activation_timestamp or 0)if delta<0.5 and art==self.last_activated_articulation then
force_insert=true
if refocus then
self:refocus_delayed(0)end
end
end
self.last_activation_timestamp=reaper.time_precise()if force_insert and force_insert~=0 then
local midi_take,midi_track
local hwnd=reaper.MIDIEditor_GetActive()if not insert_at_cursor then
if hwnd then
midi_take=reaper.MIDIEditor_GetTake(hwnd)end
if not hwnd and rfx.current.track then
for idx=0,reaper.CountTrackMediaItems(rfx.current.track)-1 do
local item=reaper.GetTrackMediaItem(rfx.current.track,idx)local itemtake=reaper.GetActiveTake(item)if reaper.BR_IsMidiOpenInInlineEditor(itemtake)then
local idx=reaper.MIDI_EnumSelNotes(itemtake,-1)if idx~=-1 then
local selected=reaper.IsMediaItemSelected(item)if not selected then
midi_take=midi_take or itemtake
else
midi_take=itemtake
break
end
end
end
end
end
if midi_take and reaper.ValidatePtr(midi_take, 'MediaItem_Take*') then
midi_track=reaper.GetMediaItemTake_Track(midi_take)end
end
reaper.PreventUIRefresh(1)reaper.Undo_BeginBlock2(0)local rfxtrack=rfx.Track()local did_multi_item_insert=false
if reaper.MIDIEditor_EnumTakes and hwnd and not insert_at_cursor then
for i=0,reaper.CountMediaItems(0)do
local take=reaper.MIDIEditor_EnumTakes(hwnd,i,true)if not take or not reaper.ValidatePtr2(0, take, "MediaItem_Take*") then
break
end
local track=reaper.GetMediaItemTake_Track(take)if rfxtrack:presync(track)then
if self:_insert_articulation(rfxtrack,nil,art.program,srcchannel,take,false,true,false)then
did_multi_item_insert=true
end
end
end
end
if not did_multi_item_insert then
for i=0,reaper.CountSelectedTracks(0)-1 do
local track=reaper.GetSelectedTrack(0,i)local take=midi_track==track and midi_take
if track==rfx.current.track then
self:_insert_articulation(rfx.current,bank,art.program,srcchannel,take)elseif rfxtrack:presync(track)then
self:_insert_articulation(rfxtrack,nil,art.program,srcchannel,take)end
end
end
rfx.current:opcode(rfx.OPCODE_ADVANCE_HISTORY)rfx.current:opcode_flush()reaper.Undo_EndBlock2(0, "Reaticulate: insert articulation (" .. art.name .. ")", UNDO_STATE_ITEMS | UNDO_STATE_FX)reaper.PreventUIRefresh(-1)art.button.start_insert_animation()else
rfx.current:activate_articulation(srcchannel,art.program)local ntracks=reaper.CountSelectedTracks(0)if ntracks>1 then
local rfxtrack=rfx.Track()for i=0,ntracks-1 do
local track=reaper.GetSelectedTrack(0,i)if track~=rfx.current.track and rfxtrack:presync(track)then
rfxtrack:activate_articulation(srcchannel,art.program)end
end
end
self:_stuff_articulation_pc(art,srcchannel)end
local idx=(srcchannel+1)+(art.group<<8)self.pending_articulations[idx]=art
self.last_activated_articulation=art
local banklist=self.screens.banklist
if banklist.selected_articulation then
rtk.defer(banklist.clear_selected_articulation)end
log.time_end('app: done activation/insert')end
function App:activate_articulation_if_exists(art,refocus,force_insert,insert_at_cursor)if art then
self:activate_articulation(art,refocus,force_insert,nil,insert_at_cursor)else
feedback.sync(self.track,feedback.SYNC_ARTICULATIONS)end
end
function App:insert_last_articulation(channel)local art=self.last_activated_articulation
if not art then
art=self:get_active_articulation(channel)end
if art then
self:activate_articulation(art,false,true,channel)end
end
function App:activate_relative_articulation_in_group(channel,group,distance)local target
local banklist=self.screens.banklist
local current=self:get_active_articulation(channel,group)if current then
target=banklist.get_relative_articulation(current,distance,group)else
target=banklist.get_firstlast_articulation(distance<0)end
if target then
self:activate_articulation(target,false,false)end
end
function App:activate_selected_articulation(channel,refocus,force_insert,insert_at_cursor)local banklist=self.screens.banklist
local current=banklist.get_selected_articulation()if not current then
current=self.last_activated_articulation
end
if current then
self:activate_articulation(current,refocus,force_insert,channel,insert_at_cursor)rtk.defer(banklist.clear_filter)end
end
function App:refocus_delayed(delay,hwnd,defer)hwnd=hwnd or self.saved_focus_window
if hwnd==rtk.focused_hwnd then
return
end
local now=reaper.time_precise()if delay then
if not self.refocus_target_time then
defer=true
end
self.refocus_target_time=now+delay
elseif not self.refocus_target_time then
return
end
if now>=self.refocus_target_time then
self.refocus_target_time=nil
self:refocus(hwnd)elseif defer then
rtk.defer(self.refocus_delayed,self,nil,hwnd,true)end
end
function App:refocus(hwnd)hwnd=hwnd or self.saved_focus_window
if hwnd then
reaper.JS_Window_SetFocus(hwnd)else
if reaper.MIDIEditor_GetActive()~=nil then
local cmd=reaper.NamedCommandLookup('_SN_FOCUS_MIDI_EDITOR')if cmd~=0 then
reaper.Main_OnCommandEx(cmd,0,0)end
else
reaper.Main_OnCommandEx(reaper.NamedCommandLookup('_BR_FOCUS_ARRANGE_WND'), 0, 0)end
end
end
function rfx.onunsubscribe()app.screens.banklist.save_scroll_position()end
function rfx.onartchange(channel,group,last_program,new_program,track_changed)log.debug("app: articulation change: %s -> %d  (ch=%d group=%d)", last_program, new_program, channel, group)local artidx=channel+(group<<8)local last_art=app.active_articulations[artidx]
local channel_bit=2^(channel-1)if last_art then
last_art.channels=last_art.channels&~channel_bit
if last_art.channels==0 then
if last_art.button then
last_art.button:attr('flat', 'label')end
app.active_articulations[artidx]=nil
end
end
app.pending_articulations[artidx]=nil
local banks=rfx.current.banks_by_channel[channel]
if banks then
for _,bank in ipairs(banks)do
local art=bank.articulations_by_program[new_program]
if art and art.group==group then
art.channels=art.channels|channel_bit
if art.button then
art.button:attr('flat', false)end
app.active_articulations[artidx]=art
if not track_changed then
app.screens.banklist.scroll_articulation_into_view(art)end
break
end
end
end
app.window:queue_draw()end
function rfx.onnoteschange(old_notes,new_notes)if app:current_screen()==app.screens.banklist then
app.window:queue_draw()end
end
function rfx.onccchange()end
local function _cmd_arg_to_channel(arg)local channel=tonumber(arg)if channel==0 then
return app.default_channel
else
return channel
end
end
local function _cmd_arg_to_distance(mode,resolution,offset)mode=tonumber(mode)resolution=tonumber(resolution)offset=tonumber(offset)if mode==2 and offset%15==0 then
return-offset/15
else
local sign=offset<0 and-1 or 1
return sign*math.ceil(math.abs(offset)*16.0/resolution)end
end
function App:handle_command(cmd,arg)if cmd=='set_default_channel' then
self:set_default_channel(tonumber(arg))elseif cmd=='activate_articulation' and rfx.current:valid() then
local args=string.split(arg, ',')local channel=_cmd_arg_to_channel(args[1])local program=tonumber(args[2])local force_insert=tonumber(args[3])or nil
local art=nil
for _,bank in ipairs(self.screens.banklist.visible_banks)do
if bank.srcchannel==17 or bank.srcchannel==channel then
art=bank:get_articulation_by_program(program)if art then
break
end
end
end
self:activate_articulation_if_exists(art,false,force_insert)elseif cmd=='activate_articulation_by_slot' and rfx.current:valid() then
local args=string.split(arg, ',')local channel=_cmd_arg_to_channel(args[1])local slot=tonumber(args[2])local art=nil
for _,bank in ipairs(self.screens.banklist.visible_banks)do
if bank.srcchannel==17 or bank.srcchannel==channel then
if slot>#bank.articulations then
slot=slot-#bank.articulations
else
art=bank.articulations[slot]
break
end
end
end
self:activate_articulation_if_exists(art,false,nil)elseif cmd=='activate_relative_articulation' and rfx.current:valid() then
local args=string.split(arg, ',')local channel=_cmd_arg_to_channel(args[1])local group=tonumber(args[2])local distance=_cmd_arg_to_distance(args[3],args[4],args[5])self:activate_relative_articulation_in_group(channel,group,distance)elseif cmd=='select_relative_articulation' and rfx.current:valid() then
local args=string.split(arg, ',')local distance=_cmd_arg_to_distance(args[1],args[2],args[3])self.screens.banklist.select_relative_articulation(distance)elseif cmd=='activate_selected_articulation' and rfx.current:valid() then
local args=string.split(arg, ',')local channel=_cmd_arg_to_channel(args[1])self:activate_selected_articulation(channel,false)elseif cmd=='insert_articulation' then
local args=string.split(arg, ',')local channel=_cmd_arg_to_channel(args[1])self:insert_last_articulation(channel)elseif cmd=='sync_feedback' and rfx.current:valid() then
if self.track then
reaper.CSurf_OnTrackSelection(self.track)feedback.sync(self.track)end
elseif cmd=='focus_filter' then
self.screens.banklist.focus_filter()elseif cmd=='select_last_track' then
if self.last_track and reaper.ValidatePtr2(0, self.last_track, "MediaTrack*") then
self:select_track(self.last_track,false)end
elseif cmd=='set_toggle_option' then
local args=string.split(arg, ',')local cfgitem=args[1]
local enabled=tonumber(args[2])local section_id=tonumber(args[3])local cmd_id=tonumber(args[4])local store=tonumber(args[5])self:set_toggle_option(cfgitem,enabled,store,section_id,cmd_id)elseif cmd=='set_option' then
local args=string.split(arg, ',')local cfgitem=args[1]
local value=args[2]
local type=args[3]
if type=='number' then
value=tonumber(value)elseif type == 'boolean' or type == 'bool' then
value = (value == '1' or value == 'true') and true or false
end
self:set_option(cfgitem,value)end
return BaseApp.handle_command(self,cmd,arg)end
function App:set_toggle_option(cfgitem,enabled,store,section_id,cmd_id)local value=self:get_toggle_option(cfgitem)if enabled==-1 then
value=not value
elseif type(enabled)=='boolean' then
value=enabled
else
value=(enabled==1 and true or false)end
if store~=false and store~=0 then
self.config[cfgitem]=value
self:queue_save_config()end
log.info("app: set toggle option: %s -> %s", cfgitem, value)if not cmd_id and self.config_map_to_script[cfgitem] then
local section,filename=table.unpack(self.config_map_to_script[cfgitem])local script=Path.join(Path.basedir, 'actions', filename)local cmd=reaper.AddRemoveReaScript(true,section,script,false)if cmd>0 then
section_id=section
cmd_id=cmd
end
end
if cmd_id then
reaper.SetToggleCommandState(section_id,cmd_id,value and 1 or 0)reaper.RefreshToolbar2(section_id,cmd_id)end
if self:current_screen()==self.screens.settings then
self.screens.settings.update()end
if cfgitem=='single_floating_instrument_fx_window' then
self:do_single_floating_fx()elseif cfgitem=='cc_feedback_active' then
feedback.set_active(value)feedback.sync(self.track)end
return value
end
function App:get_toggle_option(cfgitem)return self.config[cfgitem]
end
function App:set_option(cfgitem,value)self.config[cfgitem]=value
self:queue_save_config()if self:current_screen()==self.screens.settings then
self.screens.settings.update()end
end
function App:set_default_channel(channel)self.default_channel=channel
self.screens.banklist.highlight_channel_button(channel)if self.midi_hwnd then
reaper.MIDIEditor_OnCommand(self.midi_hwnd,40482+channel-1)end
local track=self.midi_editor_track or self.track
if not track then
return rfx.set_gmem_global_default_channel(channel)end
local rfxtrack=(track==self.track)and rfx.current or rfx.get_track(track)if not rfxtrack then
return rfx.set_gmem_global_default_channel(channel)end
rfxtrack:set_default_channel(channel)feedback.sync(track,feedback.SYNC_ALL)if self.config.default_channel_behavior==3 and self.midi_editor_item then
rfxtrack:set_item_userdata_key(self.midi_editor_item, 'default_channel', channel)end
end
function App:sync_default_channel_from_rfx()local track=self.midi_editor_track or self.track
if not track then
return
end
local rfxtrack=(track==self.track)and rfx.current or rfx.get_track(track)if not rfxtrack or not rfxtrack.appdata then
return
end
if self.config.default_channel_behavior~=1 then
local channel=rfxtrack.appdata.defchan
if self.config.default_channel_behavior==3 and self.midi_editor_item then
local itemdata=rfxtrack:get_item_userdata(self.midi_editor_item)if not itemdata.default_channel then
self:set_default_channel(channel or self.default_channel)return
end
channel=itemdata.default_channel
end
if channel~=self.default_channel then
channel=channel or 1
self.default_channel=channel
self.screens.banklist.highlight_channel_button(channel)rfxtrack:set_default_channel(channel)feedback.sync(track,feedback.SYNC_ALL)end
end
if self.midi_hwnd then
reaper.MIDIEditor_OnCommand(self.midi_hwnd,40482+self.default_channel-1)end
end
function App:get_active_articulation(channel,group)channel=channel or self.default_channel
local groups
if group then
groups={group}else
groups={1,2,3,4}end
for _,group in ipairs(groups)do
local artidx=channel+(group<<8)local art=self.pending_articulations[artidx]
if not art then
art=self.active_articulations[artidx]
end
if art and art.button.visible then
return art
end
end
end
function App:get_articulation_color(name)local color=self.config.art_colors[name] or reabank.colors[name] or reabank.default_colors[name]
if color and color:len()>0 then
return color
end
color=reabank.colors[color]
return color or self.config.art_colors.default or reabank.colors.default or reabank.default_colors.default
end
function App:handle_ondock()BaseApp.handle_ondock(self)self:update_dock_buttons()end
function App:handle_onkeypresspost(event)BaseApp.handle_onkeypresspost(self,event)if not event.handled then
log.debug("app: keypress: keycode=%d char=%s norm=%s ctrl=%s shift=%s meta=%s alt=%s",event.keycode,event.char,event.keynorm,event.ctrl,event.shift,event.meta,event.alt
)if self:current_screen()==self.screens.banklist then
if event.keycode>=49 and event.keycode<=57 then
self:set_default_channel(event.keycode-48)elseif event.keycode==rtk.keycodes.DOWN then
self.screens.banklist.select_relative_articulation(1)elseif event.keycode==rtk.keycodes.UP then
self.screens.banklist.select_relative_articulation(-1)elseif event.keycode==rtk.keycodes.ENTER then
self:activate_selected_articulation(self.default_channel,true)elseif event.keycode==rtk.keycodes.ESCAPE then
self.screens.banklist.clear_filter()self.screens.banklist.clear_selected_articulation()end
end
if event.keycode==rtk.keycodes.SPACE then
reaper.Main_OnCommandEx(40044,0,0)self:refocus()elseif event.char=='/' then
self.screens.banklist.focus_filter()elseif event.char=='\\' and (event.ctrl or event.meta) then
self.window:close()end
end
end
function App:handle_ondropfiles(event)local contents={}for n,fname in ipairs(event.files)do
contents[#contents+1]=rtk.file.read(fname)end
local data=table.concat(contents, '\n')reabank.import_banks_from_string_with_feedback(data, string.format('%d dragged files', #event.files))end
function App:update_dock_buttons()if self.toolbar.dock then
if not self.window.docked then
self.toolbar.undock:hide()self.toolbar.dock:show()else
self.toolbar.dock:hide()self.toolbar.undock:show()end
end
end
function App:has_arrange_view_pc_names()local ok, midipeaks=reaper.get_config_var_string('midipeaks')return(tonumber(ok and midipeaks)or 1)&1==0 and
self.reaper_supports_track_data_reload
end
function App:refresh_banks(flags)log.time_start()flags=flags or 0
if flags&App.REPARSE_REABANK_FILE~=0 then
reabank.parseall()log.debug("app: refresh: reabank.parseall() done")rfx.all_tracks_sync_banks_if_hash_changed()end
if flags&App.CLEAN_UNUSED_BANKS~=0 then
log.info('app: refresh: performing GC on project banks')self:clean_unused_project_banks()end
local changes,additions=reabank.write_reabank_for_project()if self:has_arrange_view_pc_names()then
if(changes or additions)and flags&App.FORCE_RECOGNIZE_BANKS_PROJECT~=0 then
self:force_recognize_bank_change_many_tracks()elseif changes then
self:force_recognize_bank_change_many_tracks(nil,changes)elseif flags&App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK~=0 and rfx.current.track then
self:force_recognize_bank_change_one_track(rfx.current.track)end
else
self:force_recognize_bank_change_one_track(nil,true)end
rfx.current:sync(rfx.current.track,true)log.debug("app: refresh: synced RFX")self:ontrackchange(nil,self.track)log.debug("app: refresh: ontrackchange() done")self.screens.banklist.update()log.debug("app: refresh: updated screens")log.info("app: refresh: all done (flags=%s changes=%s additions=%s)", flags, changes, additions)log.time_end()self:log_msblsb_mapping()end
function App:check_banks_for_errors()if self:current_screen()==self.screens.trackcfg then
self.screens.trackcfg.update()else
self.screens.trackcfg.check_errors()end
self.screens.banklist.update_error_box()end
function rfx.onhashchange()app:check_banks_for_errors()end
function App:clear_track_reabank_mapping(track)if not rfx.get(track)then
return false
end
local fast=reaper.SNM_CreateFastString("")local ok=reaper.SNM_GetSetObjectState(track,fast,false,false)local chunk=reaper.SNM_GetFastString(fast)reaper.SNM_DeleteFastString(fast)if not ok or not chunk or not chunk:find("MIDIBANKPROGFN") then
return false
end
chunk=chunk:gsub('MIDIBANKPROGFN "[^"]*"', 'MIDIBANKPROGFN ""')local fast=reaper.SNM_CreateFastString(chunk)reaper.SNM_GetSetObjectState(track,fast,true,false)reaper.SNM_DeleteFastString(fast)return true
end
function App:force_recognize_bank_change_one_track(track,midi_editor)log.time_start()local function kick_item(item)local fast=reaper.SNM_CreateFastString("")if reaper.SNM_GetSetObjectState(item,fast,false,false)then
reaper.SNM_GetSetObjectState(item,fast,true,false)end
reaper.SNM_DeleteFastString(fast)end
if track and reaper.ValidatePtr2(0, track, 'MediaTrack*') then
if self.reaper_supports_track_data_reload then
local tracks=track and {track}self:force_recognize_bank_change_many_tracks(tracks)else
for itemidx=0,reaper.CountTrackMediaItems(track)-1 do
local item=reaper.GetTrackMediaItem(track,itemidx)kick_item(item)end
end
elseif midi_editor then
local hwnd=reaper.MIDIEditor_GetActive()if hwnd then
local take=reaper.MIDIEditor_GetTake(hwnd)if take and reaper.ValidatePtr2(0, take, 'MediaItem_Take*') then
local item=reaper.GetMediaItemTake_Item(take)kick_item(item)end
end
end
log.time_end('app: force recognize bank change: track=%s midi=%s', track, midi_editor)end
function App:force_recognize_bank_change_many_tracks(tracks,guids)call_and_preserve_selected_tracks(function()if not tracks and not guids then
log.info('app: force recognize bank change on entire project')reaper.Main_OnCommandEx(40296,0,0)else
reaper.Main_OnCommandEx(40297,0,0)if tracks then
log.info('app: force recognize bank change on %s tracks', #tracks)for _,track in ipairs(tracks)do
reaper.SetTrackSelected(track,true)end
elseif guids then
log.info('app: force recognize bank change by MSB/LSB')for idx,rfxtrack in rfx.get_tracks(0,true)do
for b in rfxtrack:get_banks()do
if guids[b.guid] then
reaper.SetTrackSelected(rfxtrack.track,true)end
end
end
end
end
log.time_start()reaper.Main_OnCommandEx(42465,0,0)log.time_end('app: invoked REAPER action to reload reabank on selected tracks')end)end
function App:beat_reaper_into_submission()log.time_start()for i=0,reaper.CountTracks(0)-1 do
local track=reaper.GetTrack(0,i)self:clear_track_reabank_mapping(track)end
self:force_recognize_bank_change_many_tracks()reaper.MB('Force-refreshed all tracks in project.', 'Refresh Project', 0)log.debug('app: finished track chunk sweep')log.time_end()end
function App:build_frame()BaseApp.build_frame(self)local menubutton=rtk.OptionMenu{icon='edit',flat=true,icononly=true,tooltip='Manage banks',}if rtk.os.windows then
menubutton:attr('menu', {'Import Banks from Clipboard','Edit in Notepad','Open in Default App','Show in Explorer'})elseif rtk.os.mac then
menubutton:attr('menu', {'Import Banks from Clipboard','Edit in TextEdit','Open in Default App','Show in Finder'})else
menubutton:attr('menu', {'Import Banks from Clipboard','Edit in Editor','Show in File Browser',})end
local toolbar=self.toolbar
toolbar:add(menubutton)menubutton.onselect=function(self)reabank.create_user_reabank_if_missing()if self.selected_index==1 then
local clipboard=rtk.clipboard.get()reabank.import_banks_from_string_with_feedback(clipboard, 'the clipboard')elseif rtk.os.windows then
if self.selected_index==2 then
reaper.ExecProcess('cmd.exe /C start /B notepad ' .. reabank.reabank_filename_user, -2)elseif self.selected_index==3 then
reaper.ExecProcess('cmd.exe /C start /B "" "' .. reabank.reabank_filename_user .. '"', -2)elseif self.selected_index==4 then
reaper.ExecProcess('cmd.exe /C explorer /select,' .. reabank.reabank_filename_user, -2)end
elseif rtk.os.mac then
if self.selected_index==2 then
os.execute('open -a TextEdit "' .. reabank.reabank_filename_user .. '"')elseif self.selected_index==3 then
os.execute('open -t "' .. reabank.reabank_filename_user .. '"')elseif self.selected_index==4 then
local path=Path.join(Path.resourcedir, "Data")os.execute('open "' .. path .. '"')end
else
if self.selected_index==2 then
os.execute('xdg-open "' .. reabank.reabank_filename_user .. '"')elseif self.selected_index==3 then
local path=Path.join(Path.resourcedir, "Data")os.execute('xdg-open "' .. path .. '"')end
end
end
local button = toolbar:add(rtk.Button{icon='sync', flat=true})button:attr('tooltip', 'Reload ReaBank files from disk')button.onclick=function(b,event)rtk.defer(function()app:refresh_banks(App.REPARSE_REABANK_FILE|App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK)if event.shift then
self:beat_reaper_into_submission()end
end)end
self.toolbar.dock = toolbar:add(rtk.Button{icon='dock_window', flat=true, tooltip='Dock window'})self.toolbar.undock = toolbar:add(rtk.Button{icon='undock_window', flat=true, tooltip='Undock window'})self.toolbar.dock.onclick=function()self.window:attr('docked', true)end
self.toolbar.undock.onclick=function()self.window:attr('docked', false)end
self:update_dock_buttons()local button = toolbar:add(rtk.Button{icon='settings', flat=true, tooltip='Manage Reaticulate Settings'})button.onclick=function()self:push_screen('settings')end
end
function App:zoom(increment)BaseApp.zoom(self,increment)if self:current_screen()==self.screens.settings then
self.screens.settings.update_ui_scale_menu()end
end
function App:gen_new_change_cookie()local cookie=rtk.uuid4()self.project_change_cookie=cookie
self.active_projects_by_cookie[cookie]=true
reaper.SetProjExtState(0, 'reaticulate', 'change_cookie', cookie)log.debug('app: generated new project cookie: %s', cookie)end
function App:select_track(track,scroll_arrange)reaper.PreventUIRefresh(1)reaper.SetOnlyTrackSelected(track)feedback.scroll_mixer(track)if scroll_arrange then
reaper.Main_OnCommandEx(40913,0,0)end
reaper.CSurf_OnTrackSelection(track)reaper.PreventUIRefresh(-1)end
function App:select_track_from_fx_window()local w=rtk.focused_hwnd
while w~=nil do
local title=reaper.JS_Window_GetTitle(w)local tracknum=title:match('Track (%d+)')if tracknum then
local track=reaper.GetTrack(0,tracknum-1)self:select_track(track,true)log.debug("app: selecting track %s due to focused FX", tracknum)return true
end
w=reaper.JS_Window_GetParent(w)end
return false
end
function App:open_config_ui()self:send_command('reaticulate.cfgui', 'ping', function(response)if response==nil then
local cmd=reaper.GetExtState("reaticulate", "cfgui_command_id")if cmd=='' or not cmd or not reaper.ReverseNamedCommandLookup(tonumber(cmd)) then
cmd=reaper.NamedCommandLookup('FIXME')end
if cmd == '' or not cmd or cmd == 0 then
reaper.ShowMessageBox("Couldn't open the configuration window.  This is due to a REAPER limitation.\n\n" .."Workaround: open REAPER's actions list and manually run Reaticulate_Configuration_App.\n\n" .."You will only need to do this once.","Reaticulate: Error", 0
)else
reaper.Main_OnCommandEx(tonumber(cmd),0,0)end
else
self:send_command('reaticulate.cfgui', 'quit')end
end,0.05)end
function App:check_sloppy_focus()if not self.config.keyboard_focus_follows_mouse then
return
end
local x,y=reaper.GetMousePosition()local hwnd=reaper.JS_Window_FromPoint(x,y)if hwnd==self.last_sloppy_focus_hwnd then
return
end
self.last_sloppy_focus_hwnd=hwnd
if not hwnd or rtk.is_modal()or rtk.dragging then
return
end
local curhwnd=hwnd
local is_reaper_window=false
local known_class=nil
while curhwnd~=nil do
if curhwnd==rtk.reaper_hwnd then
is_reaper_window=true
break
end
if not known_class then
local class=reaper.JS_Window_GetClassName(curhwnd)known_class=self.known_focus_classes[class]
hwnd=curhwnd
end
curhwnd=reaper.JS_Window_GetParent(curhwnd)end
if not is_reaper_window and not known_class then
return
end
reaper.PreventUIRefresh(-1)if known_class=='arrange' then
reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND"), 0, 0)elseif known_class=='tcp' then
reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_BR_FOCUS_TRACKS"), 0, 0)elseif known_class=='midi_editor' then
reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"), 0, 0)elseif known_class=='hwnd' and hwnd then
reaper.JS_Window_SetFocus(hwnd)end
reaper.PreventUIRefresh(1)end
function App:_change_track_if_needed(hwnd,track_changed,focus_changed)if focus_changed and self.config.track_selection_follows_fx_focus then
if self:select_track_from_fx_window()then
return true
end
end
if hwnd then
local take=reaper.MIDIEditor_GetTake(hwnd)if take and reaper.ValidatePtr(take, "MediaItem_Take*") then
if take~=self.midi_editor_take then
local track=reaper.GetMediaItemTake_Track(take)local item=reaper.GetMediaItemTake_Item(take)local item_changed=item~=self.midi_editor_item
self.midi_editor_item=item
self.midi_editor_take=take
if track~=self.midi_editor_track then
self.midi_editor_track=track
if self.track~=track and self.config.track_selection_follows_midi_editor then
self:select_track(track,false)return true
end
self:sync_default_channel_from_rfx()elseif item_changed and self.config.default_channel_behavior==3 then
self:sync_default_channel_from_rfx()end
end
return false
end
end
if self.midi_editor_track then
self.midi_editor_track=nil
self.midi_editor_item=nil
self.midi_editor_take=nil
end
return false
end
function App:handle_onupdate()BaseApp.handle_onupdate(self)self:check_sloppy_focus()local track=reaper.GetLastTouchedTrack()if(track and not reaper.IsTrackSelected(track))or not track then
track=reaper.GetSelectedTrack(0,0)end
local last_track=self.track
local track_changed=self.track~=track
local current_screen=self:current_screen()local _, change_cookie=reaper.GetProjExtState(0, 'reaticulate', 'change_cookie')local dirty=reaper.IsProjectDirty(0)if change_cookie~=self.project_change_cookie then
local active=self.active_projects_by_cookie
local opened=not active[change_cookie]
self.active_projects_by_cookie={}for pidx=0,100 do
local proj, _=reaper.EnumProjects(pidx, '')if not proj then
break
end
local ok, cookie=reaper.GetProjExtState(proj, 'reaticulate', 'change_cookie')if ok and cookie ~='' then
self.active_projects_by_cookie[cookie]=true
end
end
self:gen_new_change_cookie()rfx.current:reset()self:onprojectchange(opened)elseif dirty~=self.project_dirty then
self:gen_new_change_cookie()end
self.project_dirty=dirty
local valid_before=rfx.current:valid()if rfx.current:sync(track)then
if self.screens.trackcfg.widget.visible then
self.screens.trackcfg.update()elseif not track_changed and not valid_before then
self.screens.trackcfg.check_errors()end
self.screens.banklist.update()end
local focus_changed=self.last_focused_hwnd~=rtk.focused_hwnd
if focus_changed then
self.last_focused_hwnd=rtk.focused_hwnd
if not self.window.is_focused or not self.saved_focus_window then
self.saved_focus_window=rtk.focused_hwnd
else
self.last_focus_time=reaper.time_precise()end
elseif self.last_focus_time~=nil and reaper.time_precise()-self.last_focus_time>1 then
self.saved_focus_window=rtk.focused_hwnd
self.last_focus_time=nil
end
local hwnd=reaper.MIDIEditor_GetActive()local midi_closed=self.midi_hwnd and not hwnd
self.midi_hwnd=hwnd
if track_changed then
if self.track~=nil then
self.last_track=self.track
end
self.track=track
self.midi_editor_take=nil
self:ontrackchange(last_track,track)end
local first_screen=self.screens.stack[1]
if rfx.current:valid()then
if first_screen~=self.screens.banklist then
self:replace_screen('banklist', 1)end
elseif first_screen~=self.screens.installer then
self:replace_screen('installer', 1)elseif current_screen==self.screens.trackcfg then
self:replace_screen('installer', 1)self:pop_screen()elseif current_screen==self.screens.installer then
self.screens.installer.update()end
local track_change_pending,take_changed=self:_change_track_if_needed(hwnd,track_changed,focus_changed)if not track_change_pending and rfx.current:valid()then
if track_changed or midi_closed then
self:sync_default_channel_from_rfx()end
local banklist=self.screens.banklist
if self.midi_editor_track and self.track and self.midi_editor_track~=self.track then
if not banklist.warningbox.visible then
banklist.set_warning('The selected track is different than the active take in the MIDI editor. ' ..'The articulations below may not apply to the active take.')end
elseif self.midi_editor_track==self.track or not hwnd then
if banklist.warningbox.visible then
banklist.set_warning(nil)end
end
if hwnd then
local channel=reaper.MIDIEditor_GetSetting_int(hwnd, 'default_note_chan') + 1
if channel~=self.default_channel then
self:set_default_channel(channel)end
end
end
if track_changed and not track_change_pending then
feedback.ontrackchange(last_track,track)end
rfx.opcode_commit_all()end
return App
end)()

local App=__mod_app
function main(basedir)rtk.call(App,basedir,t0,t1)end
return main
end)()
__mod_screens_banklist=(function()
local rtk=rtk
local rfx=__mod_rfx
local reabank=__mod_reabank
local articons=__mod_articons
local log=rtk.log
local screen={minw=250,widget=nil,midi_channel_buttons={},visible_banks={},toolbar=nil,errorbox=nil,warningbox=nil,button_font=nil,filter_refocus_on_activation=false,selected_articulation=nil,error_msgs={[rfx.ERROR_PROGRAM_CONFLICT]='Some banks on this track have conflicting program numbers. ' ..'Some articulations may not work as expected.',[rfx.ERROR_BUS_CONFLICT]='A bank on this track uses bus 16 which conflicts with the MIDI ' ..'controller feedback feature. Avoid the use of bus 16 in your banks ' .."or disable MIDI feedback in Reaticulate's global settings.",[rfx.ERROR_DUPLICATE_BANK]='The same bank is mapped to this track multiple times which is not ' ..'allowed.  Only one instance will appear below.',[rfx.ERROR_UNKNOWN_BANK]='A bank assigned to this track could not be found on the local system ' ..'and will not be shown below.',default='There is some issue with the banks on this track. ' ..'Open the Track Settings page to learn more.'}}local function get_filter_score(name,filter)local last_match_pos=0
local score=0
local match=false
local filter_pos=1
local filter_char=filter:sub(filter_pos,filter_pos)for name_pos=1,#name do
local name_char=name:sub(name_pos,name_pos)if name_char==filter_char then
local distance=name_pos-last_match_pos
score=score+(100-distance)if filter_pos==#filter then
return score
else
last_match_pos=name_pos
filter_pos=filter_pos+1
filter_char=filter:sub(filter_pos,filter_pos)end
end
end
return 0
end
function screen.filter_articulations(filter)for _,bank in ipairs(screen.visible_banks)do
for _,art in ipairs(bank.articulations)do
local score=-1
if filter:len()>0 then
score=get_filter_score((art.shortname or art.name):lower(),filter)end
if score~=0 then
if not art.button.visible then
art.button:show()end
elseif art.button.visible then
art.button:hide()end
end
end
end
local function handle_filter_keypress(self,event)if event.keycode==rtk.keycodes.UP or event.keycode==rtk.keycodes.DOWN then
return false
elseif event.keycode==rtk.keycodes.ESCAPE then
if screen.filter_refocus_on_activation then
app:refocus(screen.filter_refocus_on_activation)end
screen.clear_filter()return true
elseif event.keycode==rtk.keycodes.ENTER or event.keycode==rtk.keycodes.INSERT then
local force_insert=event.shift or event.ctrl or event.keycode==rtk.keycodes.INSERT
local insert_at_cursor=event.alt
if self.value ~='' then
if screen.selected_articulation then
app:activate_selected_articulation(nil,nil,force_insert,nil,insert_at_cursor)else
local art=screen.get_firstlast_articulation()if art then
app:activate_articulation(art,nil,force_insert,nil,insert_at_cursor)end
end
end
if screen.filter_refocus_on_activation then
app:refocus(screen.filter_refocus_on_activation)screen.filter_refocus_on_activation=nil
end
rtk.defer(function()screen.clear_selected_articulation()screen.clear_filter()end)return self.value ~=''end
end
function screen.draw_button_midi_channel(art,button,offx,offy,alpha,event)local hovering=button.hovering or button.hover
if not hovering and not art:is_active()then
return
end
local channels={}local bitmap=art.channels
local hover_channel=nil
if hovering then
local bank=art:get_bank()hover_channel=bank:get_src_channel(app.default_channel)-1
bitmap=bitmap|(1<<hover_channel)end
local channel=0
while bitmap>0 do
if bitmap&1>0 then
channels[#channels+1]=channel
end
bitmap=bitmap>>1
channel=channel+1
end
if channels then
local scale=rtk.scale.value
local calc=button.calc
local x=offx+calc.x+calc.w
for idx,channel in ipairs(channels)do
local text=tostring(channel+1)local lw,lh=screen.button_font:measure(text)x=x-lw-12*scale
local y=offy+calc.y+(calc.h-lh)/2
local fill=(channel==hover_channel)or(rfx.active_notes&(1<<channel)>0)button:setcolor('#ffffff', alpha)gfx.rect(x-5*scale,y-1*scale,lw+10*scale,lh+2*scale,fill)if fill then
button:setcolor('#000000', alpha)end
screen.button_font:draw(text,x,y+(rtk.os.mac and 1 or 0))end
end
end
function screen.onartclick(art,event)if event.button==rtk.mouse.BUTTON_LEFT then
app:activate_articulation(art,true,false,nil,event.alt)elseif event.button==rtk.mouse.BUTTON_MIDDLE and event.modifiers==0 then
if screen.clear_articulation(art)>0 then
rfx.current:sync(rfx.current.track,true)end
elseif event.button==rtk.mouse.BUTTON_RIGHT then
app:activate_articulation(art,true,true,nil,event.alt)end
end
function screen.clear_all_active_articulations()local cleared=0
for b in rfx.current:get_banks()do
if b.bank then
for n,art in ipairs(b.bank.articulations)do
cleared=cleared+screen.clear_articulation(art)end
end
end
if cleared>0 then
rfx.current:sync(rfx.current.track,true)end
return cleared
end
function screen.clear_articulation(art)local cleared=0
for channel=0,15 do
if art.channels&(1<<channel)~=0 then
rfx.current:clear_channel_program(channel+1,art.group)cleared=cleared+1
end
end
return cleared
end
function screen.create_banklist_ui(bank)bank.vbox=rtk.VBox{spacing=10}local hbox=rtk.HBox()bank.vbox:add(hbox,{lpadding=10,tpadding=10,bpadding=10})bank.heading=rtk.Heading{bank.shortname or bank.name}hbox:add(bank.heading, {valign='center'})hbox:add(rtk.Box.FLEXSPACE)if bank.message then
local button=rtk.Button{icon='info_outline',flat=true,alpha=bank.message and 1.0 or 0.7,tooltip='Toggle bank message',}hbox:add(button, {valign='center', rpadding=10})local msgbox=rtk.HBox{spacing=10,autofocus=true}bank.vbox:add(msgbox,{lpadding=10,rpadding=10,bpadding=10})msgbox:add(rtk.ImageBox{image='info_outline:large'}, {valign='top'})local label=msgbox:add(rtk.Text{bank.message, wrap=true}, {valign='center'})button.onclick=function()msgbox:toggle()button.alpha=msgbox.visible and 1.0 or 0.5
rfx.current:set_bank_userdata(bank, 'showinfo', msgbox.visible)end
msgbox.onclick=button.onclick
msgbox:attr('visible', rfx.current:get_bank_userdata(bank, 'showinfo') or false)button.alpha=msgbox.visible and 1.0 or 0.5
end
local artbox=bank.vbox:add(rtk.FlowBox{vspacing=7,hspacing=0,lpadding=30})for n,art in ipairs(bank.articulations)do
local color=art.color or reabank.colors.default
local darkicon=false
if not color:startswith('#') then
color=app:get_articulation_color(color)end
if rtk.color.luma(color)>rtk.light_luma_threshold then
darkicon=true
end
art.icon=articons.get(art.iconname, darkicon, 'note-eighth')art.button=rtk.Button{label=art.shortname or art.name,icon=art.icon,tooltip=art.message,color=color,padding=2,rpadding=60,tagged=true,thotzone=4,bhotzone=3,flat=art.channels==0 and 'label' or false,}art.button.onclick=function(button,event)screen.onartclick(art,event)end
art.button.onlongpress=function(button,event)app:activate_articulation(art,true,true,nil,event.alt)return true
end
art.button.ondoubleclick=art.button.onlongpress
art.button.ondraw=function(button,offx,offy,alpha,event)screen.draw_button_midi_channel(art,button,offx,offy,alpha,event)end
art.button.onmouseleave=function(button,event)if app.status==art.outputstr then
app:set_statusbar(nil)end
end
art.button.onmouseenter=function(button,event)if not art.outputstr then
art.outputstr=art:describe_outputs()end
app:set_statusbar(art.outputstr)return true
end
art.button.start_insert_animation=function()if art.button:get_animation('color') then
return
end
local target
local orig=art.button.color
local h,s,l=rtk.color.hsl(orig)if rtk.color.luma(orig)>0.8 then
target=table.pack(rtk.color.hsl2rgb(h,s*1.2,l*0.8))else
target=table.pack(rtk.color.hsl2rgb(h,s*1.2,l*1.8))end
art.button:animate{attr='color', dst=target, duration=0.15, easing='out-circ'}:after(function()art.button:animate{attr='color', dst=orig, duration=0.1, easing='out-circ'}end)end
local tpadding=art.spacer and(art.spacer&0xff)*20 or 0
artbox:add(art.button,{lpadding=0,tpadding=tpadding,fillw=true,rpadding=20,minw=250})end
bank.vbox:hide()return bank.vbox
end
function screen.show_track_banks()if not rfx.current.fx then
return
end
screen.banks:remove_all()local visible={}local visible_by_guid={}local function showbank(bank)if visible_by_guid[bank.guid] then
return
end
if not bank.vbox then
screen.create_banklist_ui(bank)end
screen.banks:add(bank.vbox:show())visible[#visible+1]=bank
visible_by_guid[bank.guid]=1
end
for b in rfx.current:get_banks()do
if b.bank then
showbank(b.bank)end
end
screen.visible_banks=visible
if #visible>0 then
screen.viewport:show()screen.no_banks_box:hide()else
screen.viewport:hide()screen.no_banks_box:show()end
if rfx.current.appdata then
local y=rfx.current.appdata.y
if y then
screen.viewport:scrollto(nil,y,false)end
end
end
function screen.set_warning(msg)if msg then
screen.warningmsg:attr('text', msg)screen.warningbox:show()screen.warningbox:animate{attr='h', src=0, dst=nil, duration=0.3}screen.warningbox:animate{attr='alpha', src=0, dst=1, duration=0.3}else
screen.warningbox:hide()end
end
function screen.update_error_box()if not rfx.current.fx or not rfx.current.appdata.err then
screen.errorbox:hide()else
local msg=screen.error_msgs[rfx.current.appdata.err] or screen.error_msgs.default
screen.errormsg:attr('text', msg)screen.errorbox:show()end
end
function screen.focus_filter()screen.filter_entry:focus()screen.filter_refocus_on_activation=not app.window.in_window and rtk.focused_hwnd
return app.window:focus()end
function screen.clear_filter()screen.filter_entry:attr('value', '')end
function screen.init()screen.button_font=rtk.Font('Calibri', 16, nil, rtk.font.BOLD)screen.widget=rtk.VBox()screen.toolbar=rtk.HBox{spacing=0}local topbar=rtk.VBox{spacing=0,bg=rtk.theme.bg,y=0,tpadding=0,bpadding=15,}screen.widget:add(topbar, {lpadding=0, halign='center'})local track_button=rtk.Button{icon='view_list',flat=true,tooltip='Configure track for Reaticulate',}track_button.onclick=function()app:push_screen('trackcfg')end
screen.toolbar:add(track_button,{rpadding=0})screen.toolbar:add(rtk.Box.FLEXSPACE)local row=rtk.HBox{spacing=2}topbar:add(row, {tpadding=20, halign='center'})for channel=1,16 do
local label=string.format("%02d", channel)local button=rtk.Button{label,w=25,h=20,color=rtk.theme.entry_border_focused,textcolor='#ffffff',fontscale=0.9,halign='center',padding=0,flat=true,tooltip='Set inserted articulations and MIDI editor to channel ' .. tostring(channel),}local button=row:add(button)button.onclick=function(button,event)if event.button==1 then
app:set_default_channel(channel)elseif event.button==2 then
log.warning('TODO: reassign selected MIDI Events to channel %s', channel)end
app:refocus()end
screen.midi_channel_buttons[channel]=button
if channel==8 then
row=rtk.HBox{spacing=2}topbar:add(row, {tpadding=0, halign='center'})end
end
local row=topbar:add(rtk.HBox{spacing=10},{tpadding=10})local entry = rtk.Entry{icon='search', placeholder='Filter articulations'}entry.onkeypress=handle_filter_keypress
entry.onchange=function(self)screen.filter_articulations(self.value:lower())end
row:add(entry,{fillw=true,lpadding=20,rpadding=20})screen.filter_entry=entry
screen.warningbox=rtk.VBox{bg=rtk.theme.dark and '#696f16' or '#ebfb74',tborder='#ccd733',bborder='#ccd733',padding=10,visible=false,}local hbox=screen.warningbox:add(rtk.HBox())hbox:add(rtk.ImageBox{image='alert_circle_outline:large', scale=1})screen.warningmsg=hbox:add(rtk.Text{wrap=true}, {lpadding=10, valign='center'})screen.widget:add(screen.warningbox,{fillw=true})screen.errorbox=rtk.VBox{bg=rtk.theme.dark and '#3f0000' or '#ff9fa6',tborder='#ff0000',bborder='#ff0000',padding={20,10},}local hbox=screen.errorbox:add(rtk.HBox())hbox:add(rtk.ImageBox{image='alert_circle_outline:large'})screen.errormsg=hbox:add(rtk.Text{wrap=true}, {lpadding=10, valign='center'})local button = rtk.Button{'Open Track Settings', icon='view_list', flat=true, color='#aa000099'}button.onclick=function()app:push_screen('trackcfg')end
screen.errorbox:add(button, {halign='center', tpadding=20})screen.widget:add(screen.errorbox,{fillw=true})screen.banks=rtk.VBox{bpadding=20,spacing=20}screen.viewport=rtk.Viewport{child=screen.banks,h=1.0}screen.widget:add(screen.viewport,{fillw=true})screen.no_banks_box=rtk.VBox()screen.widget:add(screen.no_banks_box,{halign='center', valign='center', expand=1, bpadding=100
})local label = rtk.Text{'No articulations on this track', fontsize=24, alpha=0.5}screen.no_banks_box:add(label, {halign='center'})local button=rtk.Button{'Open Track Settings',icon=track_button.icon,color={0.3,0.3,0.3,1},}screen.no_banks_box:add(button, {halign='center', tpadding=20})button.onclick=track_button.onclick
end
function screen.highlight_channel_button(new_channel)for channel,button in ipairs(screen.midi_channel_buttons)do
button:attr('flat', channel ~= new_channel and 'flat' or false)end
end
local function _get_bank_idx(bank)for idx,candidate in ipairs(screen.visible_banks)do
if bank==candidate then
return idx
end
end
end
function screen.get_bank_before(bank)local idx=_get_bank_idx(bank)-1
if idx>=1 then
return screen.visible_banks[idx]
end
end
function screen.get_bank_after(bank)local idx=_get_bank_idx(bank)+1
if idx<=#screen.visible_banks then
return screen.visible_banks[idx]
end
end
function screen.get_first_bank()return screen.visible_banks[1]
end
function screen.get_last_bank()return screen.visible_banks[#screen.visible_banks]
end
function screen.get_firstlast_articulation(last)if not last then
local bank=screen.get_first_bank()if bank then
for _,art in ipairs(bank.articulations)do
if art.button.visible then
return art
end
end
end
else
local bank=screen.get_last_bank()if bank then
for i=#bank.articulations,1,-1 do
local art=bank.articulations[i]
if art.button.visible then
return art
end
end
end
end
end
function screen.get_relative_articulation(art,distance,group)local bank=art:get_bank()local function _get_adjacent_art(art)if distance<0 then
return bank:get_articulation_before(art)else
return bank:get_articulation_after(art)end
end
local absdistance=math.abs(distance)local target=art
while absdistance>0 do
local candidate=_get_adjacent_art(target)if not candidate then
if distance<0 then
bank=screen.get_bank_before(bank)if bank then
candidate=bank:get_last_articulation()end
else
bank=screen.get_bank_after(bank)if bank then
candidate=bank:get_first_articulation()end
end
end
if not candidate then
if distance<0 then
bank=screen.get_last_bank()candidate=bank:get_last_articulation()else
bank=screen.get_first_bank()candidate=bank:get_first_articulation()end
end
if candidate then
target=candidate
if(candidate.group==group or not group)and candidate.button.visible then
absdistance=absdistance-1
end
end
end
if(target.group==group or not group)and target.button.visible then
return target
end
end
function screen.get_selected_articulation()local sel=screen.selected_articulation
if sel and sel.button.visible then
return sel
end
end
function screen.clear_selected_articulation()if screen.selected_articulation then
screen.selected_articulation.button:attr('hover', false)screen.selected_articulation=nil
end
end
function screen.select_relative_articulation(distance)local current=screen.get_selected_articulation()screen.clear_selected_articulation()if not current then
local last=app.last_activated_articulation
local group=last and last.group or nil
current=app:get_active_articulation(nil,group)end
local target
if current then
target=screen.get_relative_articulation(current,distance,nil)else
target=screen.get_firstlast_articulation(distance<0)end
if target then
target.button:attr('hover', true)screen.scroll_articulation_into_view(target)screen.selected_articulation=target
end
end
function screen.scroll_articulation_into_view(art)if art.button then
art.button:scrolltoview{50,0,10,0}end
end
function screen.save_scroll_position()if rfx.current.track and rfx.current.appdata.y~=screen.viewport.scroll_top then
rfx.current.appdata.y=screen.viewport.scroll_top
rfx.current:queue_write_appdata()end
end
function screen.clear_cache()for _,bank in pairs(reabank.banks_by_guid)do
bank.vbox=nil
end
screen.update()end
function screen.update()screen.clear_selected_articulation()screen.update_error_box()screen.show_track_banks()end
return screen
end)()
__mod_screens_installer=(function()
local rtk=rtk
local rfx=__mod_rfx
local feedback=__mod_feedback
local screen={widget=nil,last_fx_enabled=nil,last_track=nil,}function screen.init()screen.widget=rtk.Container()local box = screen.widget:add(rtk.VBox(), {halign='center', valign='center', expand=1})screen.icon = rtk.ImageBox{image='alert_circle_outline:huge', alpha=0.5, scale=1}box:add(screen.icon, {halign='center'})screen.message=rtk.Text{fontsize=24, alpha=0.5, wrap=true, padding=5, textalign='center'}box:add(screen.message, {halign='center', tpadding=10})screen.button = rtk.Button{'Add Reaticulate FX', icon='add_circle_outline', alpha=0.8}screen.button.onclick=function()reaper.PreventUIRefresh(1)reaper.Undo_BeginBlock()reaper.GetSetMediaTrackInfo_String(app.track, 'P_EXT:reaticulate', '', true)local fx=reaper.TrackFX_AddByName(app.track, 'JS:Reaticulate', 0, -1000)if fx~=-1 and not rfx.validate(app.track,fx)then
reaper.TrackFX_Delete(app.track,fx)fx=reaper.TrackFX_AddByName(app.track, 'Reaticulate.jsfx', 0, -1000)if fx~=-1 and not rfx.validate(app.track,fx)then
reaper.TrackFX_Delete(app.track,fx)fx=-1
end
end
if fx==-1 then
reaper.MB("The Reaticulate JSFX could not be found in REAPER's Effects folder, " ..'which means Reaticulate was not properly installed.  Please try ' ..'reinstalling from ReaPack.\n\nVisit https://reaticulate.com/ for more info.','Reaticulate installation error',0
)else
reaper.TrackFX_Show(app.track,fx,2)if fx>0 then
reaper.TrackFX_CopyToTrack(app.track,fx,app.track,0,true)end
end
reaper.Undo_EndBlock("Add Reaticulate FX", UNDO_STATE_FX)reaper.PreventUIRefresh(-1)rfx.current:sync(app.track,true)app:ontrackchange(nil,app.track)feedback.ontrackchange(nil,app.track)screen.update()end
box:add(screen.button, {halign='center', tpadding=20})end
function screen.update()local text='No track selected'if app.track then
local enabled=reaper.GetMediaTrackInfo_Value(app.track, "I_FXEN")if app.track==screen.last_track and enabled==screen.last_fx_enabled then
return
end
screen.last_fx_enabled=enabled
if enabled==1 then
local err=rfx.current.error
if err and err~=rfx.ERROR_MISSING_RFX then
if err==rfx.ERROR_RFX_BYPASSED then
text='The Reaticulate FX on this track is bypassed'elseif err==rfx.ERROR_UNSUPPORTED_VERSION then
text='The version of the Reaticulate FX on this track is not supported.\nTry restarting Reaper to ensure the latest versions of all scripts are running.'elseif err==rfx.ERROR_BAD_MAGIC then
text='The Reaticulate FX on this track is not recognized.'else
text=string.format('An unknown error has occurred with the Reaticulate FX (%s)', err)end
screen.icon:show()screen.button:hide()else
text='Reaticulate is not enabled for this track'screen.icon:hide()screen.button:show()end
else
text='Unbypass FX chain to enable'screen.icon:show()screen.button:hide()end
else
screen.icon:hide()screen.button:hide()end
if text~=screen.message.label then
screen.message:attr('text', text)end
screen.last_track=app.track
end
return screen
end)()
__mod_screens_settings=(function()
local rtk=rtk
local feedback=__mod_feedback
local articons=__mod_articons
local reabank=__mod_reabank
local rfx=__mod_rfx
local metadata=metadata
local log=rtk.log
local screen={minw=200,widget=nil,chase_ccs_dirty=false,art_colors={{'Default', 'default', 'note-whole'},{'Short', 'short', 'note-eighth'},{'Short Light', 'short-light', 'staccato-con-sord'},{'Short Dark', 'short-dark', 'pizz-bartok'},{'Legato', 'legato', 'legato'},{'Legato Light', 'legato-light', 'legato-flautando'},{'Legato Dark', 'legato-dark', 'legato-sul-pont'},{'Long', 'long', 'note-whole'},{'Long Light', 'long-light', 'sul-tasto'},{'Long Dark', 'long-dark', 'sul-pont'},{'Textured', 'textured', 'frozen'},{'FX', 'fx', 'fx'}},art_color_entries={}}local startup_script=[[
-- Begin Reaticulate startup stanza (don't edit this line)
local sep = package.config:sub(1, 1)
local script = debug.getinfo(1, 'S').source:sub(2)
local basedir = script:gsub('(.*)' .. sep .. '.*$', '%1')
dofile(basedir .. sep .. 'Reaticulate' .. sep .. 'actions' .. sep .. 'Reaticulate_Start.lua')
-- End Reaticulate startup stanza (don't edit this line)
]]
local function update_startup_action(start)local scriptfile=Path.join(reaper.GetResourcePath(), 'Scripts', '__startup.lua')local script=rtk.file.read(scriptfile) or ''script=script:gsub('\n*-- Begin Reaticulate.*-- End Reaticulate[^\n]*', '')if start then
script=script .. '\n\n' .. startup_script
end
rtk.file.write(scriptfile,script)end
local function make_section(parent,title)local vbox=rtk.VBox{spacing=10,lpadding=20,bpadding=30}local heading=rtk.Heading{title}vbox:add(heading,{lpadding=-10,tpadding=20,bpadding=5})return parent:add(vbox)end
local function add_row(section,label,w,spacing)local row=section:add(rtk.HBox{spacing=10},{spacing=spacing})row.label=row:add(rtk.Text{label,w=w,halign=rtk.Widget.RIGHT,wrap=false},{valign=rtk.Widget.CENTER})return row
end
local function add_tip(section,lpadding,text)local label=rtk.Text{text,wrap=true}return section:add(label, {lpadding=lpadding, valign='center'})end
local function add_color_input(row,initial,default,icon,pad,onset)local text = row:add(rtk.Entry{placeholder=default, textwidth=7}, {valign='center', fillw=false})local attrs={icon=icon,color=(initial and initial ~='') and initial or default,}if not pad then
attrs.padding=2
else
attrs.gradient=0
end
local button = row:add(rtk.Button(attrs), {valign='center', spacing=5})local undo = row:add(rtk.Button{icon='undo', flat=true, lpadding=5, rpadding=5})undo:attr('disabled', initial == nil or initial == default or initial == '')undo.onclick=function()text:attr('value', default)end
button.onclick=function()local bg=(text.value and #text.value > 0) and text.value or default or ''local hwnd=reaper.BR_Win32_HwndToString(app.window.hwnd)hwnd=reaper.BR_Win32_StringToHwnd(hwnd)local ok,color=reaper.GR_SelectColor(hwnd,rtk.color.int(bg,true))if ok~=0 then
text:push_undo()text:attr('value', rtk.color.int2hex(color, true))end
end
text.onchange=function(text)if text.value==default then
text:attr('value', '', false)end
local bg=(text.value and #text.value > 0) and text.value or default or ''undo:attr('disabled', bg == default or bg == '')button:attr('color', bg)if onset then
onset(text,button,bg)end
end
text:attr('value', initial)return text
end
function screen.init()screen.vbox=rtk.VBox{rpadding=20}screen.widget=rtk.Viewport{screen.vbox}screen.toolbar=rtk.HBox{spacing=0}local back_button = rtk.Button{'Back', icon='arrow_back', flat=true}back_button.onclick=function()if screen.chase_ccs_dirty then
reabank.clear_chase_cc_list_cache()rfx.current:sync_banks_if_hash_changed()screen.chase_ccs_dirty=false
end
app:pop_screen()end
screen.toolbar:add(back_button)if not rtk.has_js_reascript_api then
local hbox=screen.vbox:add(rtk.HBox{spacing=10},{tpadding=20,bpadding=20,lpadding=20,rpadding=20})hbox:add(rtk.ImageBox{image='warning_amber:large'}, {valign=rtk.Widget.TOP})local vbox=hbox:add(rtk.VBox())local text=vbox:add(rtk.Text{wrap=true},{valign=rtk.Widget.CENTER})text:attr('text',"Reaticulate runs best when the js_ReaScriptAPI extension is installed. " .."Several features and user experience enhancements are disabled without it.")local button = vbox:add(rtk.Button{label="Download", tmargin=10})button.onclick=function()rtk.open_url('https://forum.cockos.com/showthread.php?t=212174')end
end
local section=make_section(screen.vbox, "Behavior")local cb=rtk.CheckBox{'Autostart Reaticulate when Reaper starts'}cb.onchange=function(cb)app.config.autostart=cb.value
update_startup_action(app.config.autostart)app:save_config()end
section:add(cb)cb:attr('value', app.config.autostart == true or app.config.autostart == 1)screen.cb_insert_at_note_selection=rtk.CheckBox{'Insert articulations based on selected notes when MIDI editor is open'}screen.cb_insert_at_note_selection.onchange=function(cb)app:set_toggle_option('art_insert_at_selected_notes', cb.value, true)end
section:add(screen.cb_insert_at_note_selection)screen.cb_track_follows_midi_editor=rtk.CheckBox{'Track selection follows MIDI editor target item'}screen.cb_track_follows_midi_editor.onchange=function(cb)app:set_toggle_option('track_selection_follows_midi_editor', cb.value, true)end
section:add(screen.cb_track_follows_midi_editor)screen.cb_track_follows_fx_focus=rtk.CheckBox{'Track selection follows FX focus'}screen.cb_track_follows_fx_focus.onchange=function(cb)app:set_toggle_option('track_selection_follows_fx_focus', cb.value, true)end
screen.cb_sloppy_focus=rtk.CheckBox{'Keyboard focus follows mouse within REAPER (EXPERIMENTAL)'}screen.cb_sloppy_focus.onchange=function(cb)app:set_toggle_option('keyboard_focus_follows_mouse', cb.value, true)end
screen.cb_sloppy_focus:hide()screen.cb_single_fx_instrument=rtk.CheckBox{'Single floating instrument FX window follows selected track (EXPERIMENTAL)'}screen.cb_single_fx_instrument.onchange=function(cb)app:set_toggle_option('single_floating_instrument_fx_window', cb.value, true)app:do_single_floating_fx()end
if rtk.has_js_reascript_api then
section:add(screen.cb_track_follows_fx_focus)section:add(screen.cb_sloppy_focus)section:add(screen.cb_single_fx_instrument)end
local row=add_row(section, "Recall MIDI Channel:", 140)row:attr('tooltip', 'How Reaticulate should remember the default MIDI channel and sync with the MIDI editor')local menu=row:add(rtk.OptionMenu{menu={'Globally', 'Per Track', 'Per Item'},selected=app.config.default_channel_behavior,})menu.onchange=function(menu)app.config.default_channel_behavior=menu.selected_index
app:save_config()end
screen.default_channel_menu=menu
local row=add_row(section, "Default Chase CCs:", 140)row:attr('tooltip', 'When not explicitly specified in banks, chase these CCs. Comma delimited with optional ranges.')local entry=row:add(rtk.Entry{value=app.config.chase_ccs,placeholder=reabank.DEFAULT_CHASE_CCS})entry.onchange=function()app.config.chase_ccs=entry.value
app:save_config()screen.chase_ccs_dirty=true
end
local section=make_section(screen.vbox, "User Interface")screen.cb_undocked_borderless=rtk.CheckBox{'Use borderless window when undocked'}screen.cb_undocked_borderless.onchange=function(cb)app.config.borderless=cb.value
app.window:attr('borderless', app.config.borderless)app:save_config()end
if rtk.has_js_reascript_api then
section:add(screen.cb_undocked_borderless)end
screen.cb_touchscroll=rtk.CheckBox{'Enable touch-scrolling for touchscreen displays'}screen.cb_touchscroll.onchange=function(cb)app.config.touchscroll=cb.value
rtk.touchscroll=cb.value
app:save_config()end
section:add(screen.cb_touchscroll)screen.cb_smoothscroll=rtk.CheckBox{'Enable smoooth scrolling (in Reaticulate only)'}screen.cb_smoothscroll.onchange=function(cb)app.config.smoothscroll=cb.value
rtk.smoothscroll=cb.value
app:save_config()end
section:add(screen.cb_smoothscroll)local row=add_row(section, "UI Scale:", 85, 2)row:attr('tooltip', "Adjusts the scale of Reaticulate's UI. You can also use ctrl-mousewheel.")local menu=row:add(rtk.OptionMenu{menu={{'50%', id=0.5},{'70%', id=0.7},{'80%', id=0.8},{'90%', id=0.9},{'100%', id=1.0},{'110%', id=1.1},{'120%', id=1.2},{'130%', id=1.3},{'150%', id=1.5},{'170%', id=1.7},{'200%', id=2.0},{'250%', id=2.5},{'300%', id=2.7},},selected=rtk.scale.user,})menu.onchange=function(menu,item)if item and item.id~=rtk.scale.user then
rtk.scale.user=tonumber(item.id)app.config.scale=rtk.scale.user
app:save_config()rtk.defer(function()menu:scrolltoview(50,nil,nil,false)end)end
end
screen.ui_scale_menu=menu
local row=add_row(section, "Background:", 85)add_color_input(row, app.config.bg, rtk.color.get_reaper_theme_bg(), 'edit', true,function(text,button)local cfgval=text.value
if text.value~=app.config.bg then
app.config.bg=text.value
app:save_config()end
end
)add_tip(section, 95, 'Leave blank to detect from theme. Restart required.')local section=make_section(screen.vbox, "Feedback to Control Surface")local row=section:add(rtk.HBox{spacing=5,alpha=0.6,bpadding=10})row:add(rtk.ImageBox{'info_outline'})row:add(rtk.Text{wrap=true,'Transmit articulation changes and all CC values on the default ' ..'channel to the selected device. Control surfaces with motorized ' ..'faders will move in realtime during playback.'})local row=add_row(section, "MIDI Device:", 85, 2)local menu=row:add(rtk.OptionMenu())menu.onchange=function(menu)local device=tonumber(menu.selected_id)if app.config.cc_feedback_device==device then
return
end
log.info('settings: new MIDI feedback device: %s', device)log.time_start()app.config.cc_feedback_device=device
app:save_config()if app.config.cc_feedback_device==-1 then
feedback.destroy_feedback_track()else
feedback.ensure_feedback_track()feedback.update_feedback_track_settings(true)end
app:check_banks_for_errors()log.time_end('settings: finished changing MIDI feedback device')end
screen.midi_device_menu=menu
local box=section:add(rtk.HBox{tpadding=5,bpadding=0})local s=box:add(rtk.Spacer{w=85,h=10},{spacing=0})local prefs = box:add(rtk.Button{icon='settings', flat=true}, {valign='center', lpadding=5})local info=add_tip(box, 0, 'Device must be enabled for output')prefs.onclick=function()reaper.ViewPrefs(153, '')end
local row=add_row(section, "MIDI Bus:", 85)local menu=row:add(rtk.OptionMenu())menu:attr('menu', {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'})menu:select(app.config.cc_feedback_bus or 1)menu.onchange=function(menu)if app.config.cc_feedback_bus==menu.selected_index then
return
end
log.info("settings: changed MIDI CC feedback bus: %s", menu.selected_index)app.config.cc_feedback_bus=menu.selected_index
app:save_config()feedback.update_feedback_track_settings(true)end
local row=add_row(section, "Articulations:", 85)local menu=row:add(rtk.OptionMenu())menu:attr('menu', {"Program Changes", "CC values"})local row=add_row(section, "CC #:", 85)local text=row:add(rtk.Entry{placeholder="CC number"})text.onchange=function(text)local cc=tonumber(text.value)if app.config.cc_feedback_articulations_cc==cc then
return
end
app.config.cc_feedback_articulations_cc=tonumber(text.value)app:save_config()feedback.update_feedback_track_settings(true)end
menu.onchange=function(menu)local changed=app.config.cc_feedback_articulations~=menu.selected_index
app.config.cc_feedback_articulations=menu.selected_index
if menu.selected_index==1 then
row:hide()else
if app.config.cc_feedback_articulations_cc>0 then
text:attr('value', tostring(app.config.cc_feedback_articulations_cc))end
row:show()end
if changed then
feedback.update_feedback_track_settings(true)app:save_config()end
end
screen.cc_feedback_articulations_menu=menu
local section=make_section(screen.vbox, "Default Articulation Colors")local box=section:add(rtk.FlowBox{vspacing=5,hspacing=20})for _,record in ipairs(screen.art_colors)do
local name,color,iconname=table.unpack(record)local row=add_row(box, name .. ":", 80)local default=reabank.default_colors[color]
local initial=app.config.art_colors[color]
local icon=articons.get_for_bg(iconname,initial or default)local text=add_color_input(row,initial,default,icon,false,function(text,button)local cfgval=text.value
if cfgval==default or cfgval=='' then
cfgval=nil
end
if cfgval~=app.config.art_colors[color] then
app.config.art_colors[color]=cfgval
app:save_config()app.screens.banklist.clear_cache()end
local icon=articons.get_for_bg(iconname,cfgval or default)button:attr('icon', icon)end)screen.art_color_entries[color]=text
end
local section=make_section(screen.vbox, "Misc Settings")local row=add_row(section, "Log Level:", 85)local menu=row:add(rtk.OptionMenu())local options={}for level,name in pairs(log.levels)do
name=name:sub(1,1):upper()..name:sub(2):lower()options[#options+1]={name,id=level}end
table.sort(options,function(a,b)return a.id>b.id end)menu:attr('menu', options)menu:select(app.config.debug_level or log.ERROR)menu.onchange=function(menu)app:set_debug(tonumber(menu.selected_id))end
screen.vbox:add(rtk.Text{string.format("Reaticulate %s", metadata._VERSION), alpha=0.6},{halign='center', tpadding=20})local button=screen.vbox:add(rtk.Button{icon='link', label="Visit Website",truncate=false,color=rtk.theme.accent_subtle,alpha=0.6,cursor=rtk.mouse.cursors.HAND,flat=true,padding={7,10},},{tpadding=2, halign='center', stretch=true})button.onclick=function()rtk.open_url('https://reaticulate.com')end
end
function screen.update_ui_scale_menu()screen.ui_scale_menu:select(rtk.scale.user)if not screen.ui_scale_menu.selected_id then
screen.ui_scale_menu:attr('label', 'Custom')end
end
function screen.update()local ini=rtk.file.read(reaper.get_ini_file())local bitmap = tonumber(ini and ini:match("midiouts=([^\n]*)")) or 0
local menu = {{"Disabled", id='-1'}}for output=0,reaper.GetNumMIDIOutputs()-1 do
local retval, name=reaper.GetMIDIOutputName(output, "")if retval and bitmap&(1<<output)~=0 then
menu[#menu+1]={name,id=tostring(output)}end
end
screen.update_ui_scale_menu()screen.midi_device_menu:attr('menu', menu)screen.midi_device_menu:select(tostring(app.config.cc_feedback_device)or 1)screen.cb_insert_at_note_selection:attr('value', app.config.art_insert_at_selected_notes, false)screen.cb_track_follows_midi_editor:attr('value', app:get_toggle_option('track_selection_follows_midi_editor'), false)screen.cb_track_follows_fx_focus:attr('value', app:get_toggle_option('track_selection_follows_fx_focus'), false)screen.cb_sloppy_focus:attr('value', app:get_toggle_option('keyboard_focus_follows_mouse'), false)screen.cb_single_fx_instrument:attr('value', app:get_toggle_option('single_floating_instrument_fx_window'), false)screen.cb_undocked_borderless:attr('value', app.config.borderless, false)screen.cb_touchscroll:attr('value', app.config.touchscroll, false)screen.cb_smoothscroll:attr('value', app.config.smoothscroll, false)screen.default_channel_menu:select(app.config.default_channel_behavior)for color,text in pairs(screen.art_color_entries)do
text:attr('value', app:get_articulation_color(color), true)end
screen.cc_feedback_articulations_menu:select(app.config.cc_feedback_articulations or 2)end
return screen
end)()
__mod_screens_trackcfg=(function()
local rtk=rtk
local rfx=__mod_rfx
local reabank=__mod_reabank
local feedback=__mod_feedback
local log=rtk.log
local screen={minw=250,max_bankui_width=650,widget=nil,banklist=nil,track=nil,track_select_feedback_menu=nil,error=nil
}local function channel_menu_to_channel(id)local n=tonumber(id)return n&0xff,(n&0xff00)>>8
end
local function printable_guid(guid,name)local prefix=name and string.format('%s with ', name) or ''if type(guid)=='number' or tonumber(guid) then
guid=tonumber(guid)return string.format('%sMSB/LSB %d/%d', prefix, (guid >> 8) & 0xff, guid & 0xff)else
return string.format('%sGUID %s', prefix, guid)end
end
function screen.init()local vbox=rtk.VBox()screen.widget=rtk.Viewport{child=vbox,rpadding=10}screen.toolbar=rtk.HBox{spacing=0}local back_button = rtk.Button{'Back', icon='arrow_back', flat=true}back_button.onclick=function()app:pop_screen()end
screen.toolbar:add(back_button)vbox:add(rtk.Heading{'Track Articulations', margin={10, 0, 10, 10}})screen.banklist=vbox:add(rtk.VBox{spacing=10},{lpadding=10})local spacer=rtk.Spacer{h=1.0, w=1.0, y=0, z=10, position='absolute'}spacer.ondropfocus=function(self,event,src,srcbankbox)screen.move_bankbox(srcbankbox,nil)return true
end
vbox:add(spacer)local add_bank_button = rtk.Button{label='Add Bank to Track', icon='add_circle_outline', color='#2d5f99'}add_bank_button.onclick=function()if #screen.banklist.children>=rfx.MAX_BANKS then
reaper.ShowMessageBox("You have reached the limit of banks for this track.","Too many banks :(", 0)else
local bankbox=screen.create_bank_ui(nil,17,17,1)screen.banklist:add(bankbox,{xmaxw=screen.max_bankui_width})bankbox.bank_menu.onchange()end
end
vbox:add(add_bank_button,{lpadding=20,tpadding=20})vbox:add(rtk.Heading{'Track Tweaks', margin={40, 0, 10, 10}})local section=vbox:add(rtk.VBox{spacing=10,margin={0,10,0,20}})section:add(rtk.Button{'Fix numeric articulation names',icon='auto_fix',tooltip='Removes any non-Reaticulate ReaBank assignment from this track to ' ..'fix numeric Program Change event names (e.g. 43-1-22)',flat=true,onclick=function()if screen.error==rfx.ERROR_UNKNOWN_BANK then
return reaper.MB("This track has banks assigned that aren't currently installed on this system, " .."which is the likely cause of numeric articulation names.\n\nPlease first select " .."an available bank.",'User action required',0
)end
local cleared=app:clear_track_reabank_mapping(rfx.current.track)if cleared then
log.info('trackcfg: cleared non-Reaticulate bank on current track')end
app:force_recognize_bank_change_one_track(rfx.current.track)local n_remapped=0
if #screen.banklist.children==1 then
local bankbox=screen.banklist:get_child(1)local guid=bankbox.bank_menu.selected_id
local bank=reabank.get_bank_by_guid(guid)n_remapped=remap_bank_select(rfx.current.track,nil,bank)log.info('trackfg: remapped %s bank select events on track', n_remapped)end
rtk.defer(reaper.MB,"Reaticulate tried to correct common issues causing numeric articulation names" ..((cleared or n_remapped > 0) and ' (and did find some things to fix)' or '') ..".\n\nIf you still see numeric articulation names, the likely reason is that " .."the articulations don't actually exist in the current banks assigned to this track. " .."This is usually caused by inserting articulations with some other bank and then " .."later removing that bank from the track.\n\nIf that's the case, you'll need " .."to replace the articulations in the MIDI editor manually.",'Fix Numeric Articulation Names',0
)end
})section:add(rtk.Button{'Clear active articulations in UI',icon='eraser',tooltip='Clears all articulation selections on all channels in the GUI. This can also be done per ' ..'articulation by middle-clicking the articulation.',flat=true,onclick=function()local n=app.screens.banklist.clear_all_active_articulations()local msg=string.format('Cleared %d articulation assignments on this track', n)rtk.defer(reaper.MB, msg, 'Clear Articulations', 0)end
})vbox:add(rtk.Heading{'Advanced Settings', margin={40, 0, 10, 10}})local section=vbox:add(rtk.VBox{spacing=10,margin={0,10,0,20}})screen.create_track_feedback_option(section)screen.src_channel_menu = {{'Omni', id=17}}for i=1,16 do
screen.src_channel_menu[#screen.src_channel_menu+1]={string.format('Ch %d', i),id=i
}end
screen.dst_channel_menu={{'Bus 1', disabled=true},rtk.NativeMenu.SEPARATOR,{'Source', id=17 | (1 << 8)}}for i=1,16 do
screen.dst_channel_menu[#screen.dst_channel_menu+1]={string.format('Ch %d', i),id=i|(1<<8)}end
screen.dst_channel_menu[#screen.dst_channel_menu+1]=rtk.NativeMenu.SEPARATOR
for i=2,16 do
local submenu = {{'Source', id=17 | (i << 8), altlabel=string.format('%d/Source', i, 0)}}for j=1,16 do
submenu[#submenu+1]={string.format('Ch %d', j),id=j|(i<<8),altlabel=string.format('Ch %d/%d', i, j)}end
screen.dst_channel_menu[#screen.dst_channel_menu+1]={string.format('Bus %d', i),submenu=submenu
}end
screen.update()end
function screen.create_track_feedback_option(section)local tooltip="Sends the given MIDI message(s) to the control surface (configured in Reaticulate's " .."settings) whenever this track is selected.\n\nThis message is sent before the " .."messages for current articulation and current CC values."local row=section:add(rtk.HBox{spacing=10, valign='center'})row:add(rtk.Text{'Feedback on Track Select',xfontflags=rtk.font.BOLD,tooltip=tooltip,})local subsection=section:add(rtk.VBox{spacing=10,maxw=350})local options={}local row=subsection:add(rtk.HBox{spacing=10, lpadding=10, valign='center'})local labelw=45
row:add(rtk.Text{'MIDI:', w=labelw, halign='right', tooltip=tooltip})local menu=row:add(rtk.OptionMenu{tooltip=tooltip},{fillw=true})menu:attr('menu', {{'Disabled', id='disabled', args={}},{'Bank Select', id='bankselect', args={'MSB #', 'LSB #'}},{'Program Change', id='program', args={'Program #'}},{'CC', id='cc', args={'CC #', 'Val'}},{'Note', id='note', args={'Note #', 'Vel'}},{'Note On', id='note-on', args={'Note #', 'Vel'}},{'Note Off', id='note-off', args={'Note #', 'Vel'}},{'Raw MIDI', id='raw', args={'MIDI hex bytes'}},})local channels={}for i=1,16 do
channels[#channels+1]=string.format('Ch %d', i)end
local error
local feedback_data_onchange=function()local msgs={}local item=menu.selected_item
local selected=menu.selected_index
local row=options[selected]
if row then
local data1=row.data1.value
local data2=row.data2 and row.data2.value
local channel=row.channel and row.channel.selected_index
if item.id=='raw' then
msgs[#msgs+1]={type=item.id,data1=data1}else
msgs[#msgs+1]={type=item.id,channel=channel,data1=data1,data2=data2}end
end
rfx.current:set_track_data('track_select_feedback', msgs)local _,errmsg=rfx.current:sync_custom_feedback_events()error:attr('visible', errmsg and true or false)if errmsg then
error:attr('text', errmsg)end
end
for n,item in ipairs(menu.menu)do
if item.id ~='disabled' then
local row=subsection:add(rtk.HBox{spacing=10, lpadding=10+10+labelw, valign='center'})options[n]=row
if item.id=='raw' then
row.data1=row:add(rtk.Entry{placeholder='MIDI hex bytes',textwidth=9,tooltip='Arbitrarily many MIDI events (including SysEx) expressed as hexadecimal octets.' ..'\n\nFor example, "90 09 42 f0 a0 08 ee f7 80 09 00"'},{fillw=true})else
row.data1=row:add(rtk.Entry{placeholder=item.args[1]})if #item.args==2 then
row.data2=row:add(rtk.Entry{placeholder=item.args[2]})row.data2.onchange=feedback_data_onchange
end
row.channel=row:add(rtk.OptionMenu{channels,selected=1},{fillw=true})row.channel.onchange=feedback_data_onchange
end
row.data1.onchange=feedback_data_onchange
row:hide()end
end
error = subsection:add(rtk.Text{color='#ff5266', lpadding=10+10+labelw, tmargin=-8, visible=false})menu.onchange=function(menu,item,last)local lastrow=last and options[last.index]
if lastrow then
lastrow:hide()end
local newrow=item and options[item.index]
if newrow then
local msgs=rfx.current:get_track_data('track_select_feedback')local msg=msgs and msgs[1]
if newrow.channel then
newrow.channel:select(msg and msg.channel or 1,false)end
local keepd1 = not last or (last.id ~= 'raw' and item.id ~= 'raw')newrow.data1:attr('value', msg and keepd1 and msg.data1, false)if newrow.data2 then
newrow.data2:attr('value', msg and msg.data2, false)end
newrow:show()end
if item and last then
feedback_data_onchange()end
error:hide()end
screen.track_select_feedback_menu=menu
end
function screen.set_banks_from_banklist()local banks={}for n=1,#screen.banklist.children do
local bankbox=screen.banklist:get_child(n)local srcchannel,_=channel_menu_to_channel(bankbox.srcchannel_menu.selected_id)local dstchannel,dstbus=channel_menu_to_channel(bankbox.dstchannel_menu.selected_id)local guid=bankbox.bank_menu.selected_id or bankbox.fallback_guid
assert(guid, string.format('missing guid: bankbox.guid is %s (%s)', bankbox.guid, type(bankbox.guid)))local bank=reabank.get_bank_by_guid(guid)banks[#banks+1]={guid,srcchannel,dstchannel,dstbus,bank and bank.name or bankbox.fallback_name}if bank then
reabank.add_bank_to_project(bank)end
end
rfx.current:set_banks(banks)screen.check_errors_and_update_ui()rfx.current:sync_banks_to_rfx()app.screens.banklist.update()app:queue(App.FORCE_RECOGNIZE_BANKS_CURRENT_TRACK)end
function screen.move_bankbox(bankbox,target,position)if not rtk.isa(bankbox,rtk.Box)or bankbox==target then
return false
end
if target then
local bankboxidx=screen.banklist:get_child_index(bankbox)local targetidx=screen.banklist:get_child_index(target)if bankboxidx>targetidx and position<0 then
screen.banklist:reorder_before(bankbox,target)elseif targetidx>bankboxidx and position>0 then
screen.banklist:reorder_after(bankbox,target)end
else
screen.banklist:reorder(bankbox,#screen.banklist.children+1)end
return true
end
function screen.move_bankbox_finish()screen.set_banks_from_banklist()end
function screen.create_bank_ui(guid,srcchannel,dstchannel,dstbus,name)local bankbox=rtk.VBox{spacing=10,tpadding=10,bpadding=10,tborder={'#00000000', 2},bborder={'#00000000', 2},}local banklist_menu_spec=reabank.to_menu()local row=bankbox:add(rtk.HBox{spacing=10})bankbox.fallback_guid=guid
bankbox.fallback_name=name
bankbox.ondropfocus=function(self,event,_,srcbankbox)return true
end
bankbox.ondropmousemove=function(self,event,dragging,srcbankbox)if self~=srcbankbox and dragging.bankbox then
local rely=event.y-self.clienty-self.calc.h/2
if rely<0 then
screen.move_bankbox(srcbankbox,bankbox,-1)else
screen.move_bankbox(srcbankbox,bankbox,1)end
end
end
local drag_handle=rtk.ImageBox{image=rtk.Image.make_icon('drag_vertical:large'),cursor=rtk.mouse.cursors.REAPER_HAND_SCROLL,halign='center',show_scrollbar_on_drag=true,tooltip='Click-drag to reorder bank'}drag_handle.bankbox=true
drag_handle.ondragstart=function(event)bankbox:attr('bg', '#5b7fac30')bankbox:attr('tborder', {'#497ab7', 2})bankbox:attr('bborder', bankbox.tborder)return bankbox
end
drag_handle.ondragend=function(event)bankbox:attr('bg', nil)bankbox:attr('tborder', {'#00000000', 2})bankbox:attr('bborder', bankbox.tborder)screen.move_bankbox_finish()end
drag_handle.onmouseenter=function()return true end
row:add(drag_handle)local bank_menu=rtk.OptionMenu()row:add(bank_menu,{expand=1,fillw=true,rpadding=0})bankbox.bank_menu=bank_menu
bank_menu:attr('menu', banklist_menu_spec)bank_menu:select(guid and tostring(guid)or 1,false)if not bank_menu.selected_id then
local label=string.format('Unknown Bank (%s)', printable_guid(guid))bankbox.bank_menu:attr('label', label)end
local row=bankbox:add(rtk.HBox{spacing=10})row:add(rtk.Spacer{w=24,h=24})bankbox.srcchannel_menu=rtk.OptionMenu{tooltip='Source MIDI channel for bank'}row:add(bankbox.srcchannel_menu,{lpadding=0,expand=1,fillw=true})bankbox.srcchannel_menu:attr('menu', screen.src_channel_menu)bankbox.srcchannel_menu:select(tostring(srcchannel),false)row:add(rtk.Text{'→'}, {valign='center'})bankbox.dstchannel_menu=rtk.OptionMenu{tooltip='Destination MIDI channel/bus when articulations do not specify an explicit destination channel'}row:add(bankbox.dstchannel_menu,{lpadding=0,expand=1,fillw=true})bankbox.dstchannel_menu:attr('menu', screen.dst_channel_menu)bankbox.dstchannel_menu:select(tostring(dstchannel|(dstbus<<8)),false)local delete_button=rtk.Button{icon='delete',color='#9f2222',tooltip='Remove bank from track',}delete_button.delete=true
row:add(delete_button)delete_button.onclick=function()screen.banklist:remove(bankbox)screen.set_banks_from_banklist()end
bankbox.bank_menu.onchange=function(self,item,last)local bank=reabank.get_bank_by_guid(bankbox.bank_menu.selected_id)local slot=screen.banklist:get_child_index(bankbox)if not slot then
log.error("trackcfg: can't find bank in bank list")return
end
screen.set_banks_from_banklist()if bank.off~=nil then
local art=bank:get_articulation_by_program(bank.off)if art then
app:activate_articulation(art)end
end
local remap_from=false
if #screen.banklist.children==1 then
remap_from=nil
elseif last and last.id then
remap_from=reabank.get_bank_by_guid(last.id)or false
elseif bankbox.fallback_guid then
local frommsb,fromlsb
local msblsb=tonumber(bankbox.fallback_guid)if msblsb then
frommsb=(msblsb>>8)&0xff
fromlsb=msblsb&0xff
else
frommsb,fromlsb=reabank.get_project_msblsb_for_guid(bankbox.fallback_guid)end
if frommsb then
remap_from={frommsb,fromlsb}end
end
if remap_from~=false then
rtk.defer(remap_bank_select,rfx.current.track,remap_from,bank)end
bankbox.fallback_guid=nil
bankbox.fallback_name=nil
end
bankbox.srcchannel_menu.onchange=bankbox.bank_menu.onchange
bankbox.dstchannel_menu.onchange=bankbox.bank_menu.onchange
local row=bankbox:add(rtk.HBox{spacing=10})bankbox.info=row
row:add(rtk.ImageBox{'info_outline:large'}, {valign='top'})row.label=row:add(rtk.Text{wrap=true}, {valign='center'})local row=bankbox:add(rtk.HBox{spacing=10})bankbox.warning=row
row:add(rtk.ImageBox{'warning_amber:large'}, {valign='top'})row.label=row:add(rtk.Text{wrap=true}, {valign='center'})return bankbox
end
function screen.get_errors()local conflicts=rfx.current:get_banks_conflicts()local get_next_bank=rfx.current:get_banks()local feedback_enabled=feedback.is_enabled()local banks={}return function()local b=get_next_bank()if not b then
return
end
local bank=b.bank
local error=rfx.ERROR_NONE
local conflict=nil
if not bank then
error=rfx.ERROR_UNKNOWN_BANK
else
if(bank.buses&(1<<15)>0 or b.dstbus==16)and feedback_enabled then
error=rfx.ERROR_BUS_CONFLICT
end
if banks[bank] then
if not error then
error=rfx.ERROR_DUPLICATE_BANK
end
else
banks[bank]={idx=b.idx,channel=b.srcchannel}conflict=conflicts[bank]
if conflict and conflict.source~=bank then
local previous=banks[conflict.source]
if b.srcchannel==17 or(previous and(previous.channel==17 or b.srcchannel==previous.channel))then
error=rfx.ERROR_PROGRAM_CONFLICT
end
end
end
end
return b.idx,bank,b.guid or b.v,b.name,error,conflict
end
end
local function _max_error(a,b)return(a and b)and math.max(a,b)or a or b
end
function screen.check_errors_and_update_ui()local error=nil
for n,bank,guid,name,bank_error,conflict in screen.get_errors()do
local bankbox=screen.banklist:get_child(n)if bank and bank.message then
bankbox.info.label:attr('text', bank.message)bankbox.info:show()else
bankbox.info:hide()end
local errmsg=nil
if bank_error==rfx.ERROR_BUS_CONFLICT then
errmsg='Error: bank uses bus 16 which conflicts with MIDI controller feedback feature'elseif bank_error==rfx.ERROR_DUPLICATE_BANK then
errmsg='Error: bank is already listed above.'elseif bank_error==rfx.ERROR_PROGRAM_CONFLICT then
errmsg="Error: program numbers on the same source channel conflict with " .. conflict.source.name
elseif bank_error==rfx.ERROR_UNKNOWN_BANK then
errmsg=string.format('Error: This bank (%s) could not be found on this system ' ..'and will not be shown on the main screen.',printable_guid(guid,name))end
screen.set_bankbox_warning(bankbox,errmsg)error=_max_error(error,bank_error)end
screen.error=error
rfx.current:set_error(error)end
function screen.check_errors()local error=nil
for n,bank,guid,name,bank_error,conflict in screen.get_errors()do
error=_max_error(error,bank_error)end
screen.error=error
rfx.current:set_error(error)end
function screen.set_bankbox_warning(bankbox,msg)if msg then
bankbox.warning.label:attr('text', msg)bankbox.warning:show()else
bankbox.warning:hide()end
end
function screen.update()if not rfx.current.fx then
return
end
if screen.track~=rfx.current.track then
screen.widget:scrollto(0,0)screen.track=rfx.current.track
end
screen.banklist:remove_all()for b in rfx.current:get_banks()do
local bankbox=screen.create_bank_ui(b.guid or b.v,b.srcchannel,b.dstchannel,b.dstbus,b.name)screen.banklist:add(bankbox)end
screen.check_errors_and_update_ui()screen.track_select_feedback_menu:select(nil)local msgs=rfx.current:get_track_data('track_select_feedback')screen.track_select_feedback_menu:select(msgs and msgs[1] and msgs[1].type or 1)end
return screen
end)()
return rtk
