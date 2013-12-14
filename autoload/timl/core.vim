if exists("g:autoloaded_timl_core") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_core = 1

let s:true = g:timl#true
let s:false = g:timl#false

let s:dict = {}

if !exists('g:timl_functions')
  let g:timl_functions = {}
endif

let s:ns = timl#namespace#find(timl#symbol('timl.core'))

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:call(...) dict
  return self.apply(a:000)
endfunction

function! s:apply(_) dict
  return call(self.call, a:_, self)
endfunction

command! -bang -nargs=1 TLargfunction
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+'))),
      \    'call': s:function('s:call')}) |
      \ function! g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')}.apply(_) abort

command! -bang -nargs=1 TLfunction
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+'))),
      \    'apply': s:function('s:apply'),
      \    'call': function('timl#core#'.matchstr(<q-args>, '^[[:alnum:]_#]\+'))}) |
      \ function! timl#core#<args> abort

command! -bang -nargs=+ TLalias
      \ let g:timl#core#{[<f-args>][0]} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(([<f-args>][0]))),
      \    'apply': s:function('s:apply'),
      \    'call': function([<f-args>][1])})

command! -bang -nargs=1 TLexpr
      \ exe "function! s:dict.call".matchstr(<q-args>, '([^)]*)')." abort\nreturn".matchstr(<q-args>, ')\zs.*')."\nendfunction" |
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+'))),
      \    'apply': s:function('s:apply'),
      \    'call': s:dict.call}) |
      \ let g:timl_functions[join([s:dict.call])] = {'file': expand('<sfile>'), 'line': expand('<slnum>')}

command! -bang -nargs=1 TLpredicate TLexpr <args> ? s:true : s:false

" Section: Misc {{{1

TLpredicate nil_QMARK_(val) a:val is# g:timl#nil
TLexpr blessing(val) timl#keyword#intern(timl#type#string(a:val))
TLalias meta timl#meta
TLalias with_meta timl#with_meta

" }}}1
" Section: Compiler {{{1

TLpredicate special_symbol_QMARK_(sym) timl#compiler#specialp(a:sym)
TLalias macroexpand_1 timl#compiler#macroexpand_1
TLalias macroexpand_all timl#compiler#macroexpand_all

" }}}1
" Section: Functions {{{1

let s:def = timl#symbol('def')
let s:lets = timl#symbol('let*')
let s:fns = timl#symbol('fn*')
let s:fn1 = timl#symbol('timl.core/fn')
let s:defn = timl#symbol('timl.core/defn')
let s:setq = timl#symbol('set!')
let s:dot = timl#symbol('.')
let s:form = timl#symbol('&form')
let s:env = timl#symbol('&env')

TLfunction fn(form, env, ...)
  return timl#with_meta(timl#list2([s:fns] + a:000), timl#meta(a:form))
endfunction
let g:timl#core#fn.macro = g:timl#true

TLfunction defn(form, env, name, ...)
  return timl#list(s:def, a:name, timl#with_meta(timl#list2([s:fn1, a:name] + a:000), timl#meta(a:form)))
endfunction
let g:timl#core#defn.macro = g:timl#true

TLfunction defmacro(form, env, name, params, ...)
  let extra = [s:form, s:env]
  if type(a:params) == type([])
    let body = [extra + a:params] + a:000
  else
    let _ = {}
    let body = []
    for _.list in [a:params] + a:000
      call add(body, timl#cons#create(extra + timl#first(_.list), timl#next(_.list)))
    endfor
  endif
  let fn = timl#gensym('fn')
  return timl#list(s:lets,
        \ [fn, timl#list2([s:defn, a:name] + body)],
        \ timl#list(s:setq, timl#list(s:dot, fn, timl#symbol('macro')), 1),
        \ fn)
endfunction
let g:timl#core#defmacro.macro = g:timl#true

TLexpr identity(x) a:x

TLargfunction apply
  if len(a:_) < 2
    throw 'timl: arity error'
  endif
  let [F; args] = a:_
  let args = args[0:-2] + timl#ary(args[-1])
  return timl#call(F, args)
endfunction

" }}}1
" Section: Equality {{{1

TLpredicate _EQ_(...)     call('timl#equalp', a:000)
TLpredicate not_EQ_(...) !call('timl#equalp', a:000)

TLfunction! identical_QMARK_(x, ...) abort
  for y in a:000
    if a:x isnot# y
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1
" Section: Numbers {{{

TLalias num timl#num
TLalias int timl#int
TLalias float timl#float
TLpredicate integer_QMARK_(obj) type(a:obj) == type(0)
TLpredicate float_QMARK_(obj)   type(a:obj) == 5
TLpredicate number_QMARK_(obj)  type(a:obj) == type(0) || type(a:obj) == 5

TLexpr inc(x) timl#num(a:x) + 1
TLexpr dec(x) timl#num(a:x) - 1
TLexpr rem(x, y) timl#num(a:x) % a:y
TLexpr quot(x, y) type(a:x) == 5 || type(a:y) == type(5) ? trunc(a:x/a:y) : timl#num(a:x)/a:y
TLfunction mod(x, y)
  if (timl#num(a:x) < 0 && timl#num(a:y) > 0 || timl#num(a:x) > 0 && timl#num(a:y) < 0) && a:x % a:y != 0
    return (a:x % a:y) + a:y
  else
    return a:x % a:y
  endif
endfunction

TLexpr bit_not(x) invert(a:x)
TLexpr bit_or(x, y, ...)  a:0 ? call(self.call, [ or(a:x, a:y)] + a:000, self) :  or(a:x, a:y)
TLexpr bit_xor(x, y, ...) a:0 ? call(self.call, [xor(a:x, a:y)] + a:000, self) : xor(a:x, a:y)
TLexpr bit_and(x, y, ...) a:0 ? call(self.call, [and(a:x, a:y)] + a:000, self) : and(a:x, a:y)
TLexpr bit_and_not(x, y, ...) a:0 ? call(self.call, [and(a:x, invert(a:y))] + a:000, self) : and(a:x, invert(a:y))
TLfunction bit_shift_left(x, n)
  let x = timl#int(a:x)
  for i in range(timl#int(a:n))
    let x = x * 2
  endfor
  return x
endfunction
TLfunction bit_shift_right(x, n)
  let x = timl#int(a:x)
  for i in range(timl#int(a:n))
    let x = x / 2
  endfor
  return x
endfunction
TLexpr bit_flip(x, n)  xor(a:x, g:timl#core#bit_shift_left.call(1, a:n))
TLexpr bit_set(x, n)    or(a:x, g:timl#core#bit_shift_left.call(1, a:n))
TLexpr bit_clear(x, n) and(a:x, invert(g:timl#core#bit_shift_left.call(1, a:n)))
TLpredicate bit_test(x, n) and(a:x, g:timl#core#bit_shift_left.call(1, a:n))

TLexpr      not_negative(x) timl#num(a:x) < 0 ? g:timl#nil : a:x
TLpredicate zero_QMARK_(x) timl#num(a:x) == 0
TLpredicate nonzero_QMARK_(x) timl#num(a:x) != 0
TLpredicate pos_QMARK_(x) timl#num(a:x) > 0
TLpredicate neg_QMARK_(x) timl#num(a:x) < 0
TLpredicate odd_QMARK_(x) timl#num(a:x) % 2
TLpredicate even_QMARK_(x) timl#num(a:x) % 2 == 0

" }}}1
" Section: Strings {{{1

TLpredicate string_QMARK_(obj)  type(a:obj) == type('')
TLpredicate symbol_QMARK_(obj)  timl#symbol#test(a:obj)
TLpredicate keyword_QMARK_(obj) timl#keyword#test(a:obj)

TLalias symbol  timl#symbol
TLalias keyword timl#keyword
TLalias gensym  timl#gensym

TLexpr pr_str(...) join(map(copy(a:000), 'timl#printer#string(v:val)'), ' ')
TLexpr prn_str(...) join(map(copy(a:000), 'timl#printer#string(v:val)'), ' ')."\n"
TLexpr print_str(...) join(map(copy(a:000), 'timl#str(v:val)'), ' ')
TLexpr println_str(...) join(map(copy(a:000), 'timl#str(v:val)'), ' ')."\n"

TLexpr str(...) join(map(copy(a:000), 'timl#str(v:val)'), '')
TLexpr format(fmt, ...) call('printf', [timl#str(a:fmt)] + a:000)

TLfunction subs(str, start, ...)
  if a:0 && a:1 <= a:start
    return ''
  elseif a:0
    return matchstr(a:str, '.\{,'.(a:1-a:start).'\}', byteidx(a:str, a:start))
  else
    return a:str[byteidx(a:str, a:start) :]
  endif
endfunction

TLexpr join(sep_or_coll, ...)
      \ join(map(copy(a:0 ? a:1 : a:sep_or_coll), 'timl#str(v:val)'), a:0 ? a:sep_or_coll : '')
TLexpr split(s, re) split(a:s, '\C'.a:re)
TLexpr replace(s, re, repl)     substitute(a:s, '\C'.a:re, a:repl, 'g')
TLexpr replace_one(s, re, repl) substitute(a:s, '\C'.a:re, a:repl, '')
TLexpr re_quote_replacement(re) escape(a:re, '\~&')
TLfunction re_find(re, s)
  let result = matchlist(a:s, '\C'.a:re)
  return empty(result) ? g:timl#nil : timl#vec(result)
endfunction

" }}}1
" Section: Lists {{{1

TLalias list timl#list
TLpredicate list_QMARK_(val) timl#consp(a:val)
TLalias cons timl#cons#create

" }}}1
" Section: Vectors {{{1

TLpredicate vector_QMARK_(val) timl#vectorp(a:val)
TLalias vector timl#vector
TLalias vec timl#vec

TLfunction! subvec(list, start, ...) abort
  if a:0 && a:1 == 0
    return type(a:list) == type('') ? '' : timl#persistentb([])
  elseif a:0
    return timl#persistentb(a:list[a:start : (a:1 < 0 ? a:1 : a:1-1)])
  else
    return timl#persistentb(a:list[a:start :])
  endif
endfunction

" }}}1
" Section: Dictionaries {{{1

TLexpr dict(...) timl#dictionary#create(a:000)
TLexpr hash_map(...) timl#map#create(a:000)
TLexpr hash_set(...) timl#set#coerce(a:000)
TLalias set timl#set#coerce
TLpredicate map_QMARK_(x) timl#mapp(a:x)
TLpredicate set_QMARK_(x) timl#setp(a:x)
TLpredicate dict_QMARK_(x) timl#dictp(a:x)

" }}}1
" Section: Collections {{{1

TLpredicate coll_QMARK_(seq) timl#collp(a:seq)
TLalias get timl#get
TLalias into timl#into
TLpredicate contains_QMARK_(coll, val) timl#containsp(a:coll, a:val)

" }}}1
" Section: Sequences {{{1

TLalias next timl#next
TLalias rest timl#rest
TLpredicate seq_QMARK_(seq) timl#seqp(a:seq)

TLpredicate empty_QMARK_(coll) timl#core#seq(a:coll) is# g:timl#nil

TLfunction! reduce(f, coll, ...) abort
  let _ = {}
  if a:0
    let _.val = a:coll
    let _.seq = timl#seq(a:1)
  else
    let _.seq = timl#seq(a:coll)
    if empty(_.seq)
      return g:timl#nil
    endif
    let _.val = timl#first(_.seq)
    let _.seq = timl#rest(_.seq)
  endif
  while _.seq isnot# g:timl#nil
    let _.val = timl#call(a:f, [_.val, timl#first(_.seq)])
    let _.seq = timl#next(_.seq)
  endwhile
  return _.val
endfunction

" }}}1
" Section: Namespaces {{{1

TLalias require timl#require
TLalias create_ns timl#namespace#create
TLalias find_ns timl#namespace#find
TLalias the_ns timl#namespace#the
TLalias ns_name timl#namespace#name
TLalias all_ns timl#namespace#all
TLexpr ns_resolve(ns, sym, ...) timl#compiler#ns_resolve(a:ns, a:0 ? a:1 : a:sym, a:0 ? a:sym : {})
TLexpr resolve(sym, ...) timl#compiler#ns_resolve(g:timl#core#_STAR_ns_STAR_, a:0 ? a:1 : a:sym, a:0 ? a:sym : {})
TLalias in_ns timl#namespace#select
TLalias refer timl#namespace#refer
TLalias alias timl#namespace#alias
TLalias use timl#namespace#use

" }}}1

delcommand TLfunction
delcommand TLalias
delcommand TLexpr
delcommand TLpredicate
unlet s:dict

call timl#source_file(expand('<sfile>:r') . '.bootstrap.tim')
call timl#source_file(expand('<sfile>:r') . '.macros.tim')
call timl#source_file(expand('<sfile>:r') . '.basics.tim')
call timl#source_file(expand('<sfile>:r') . '.seq.tim')
call timl#source_file(expand('<sfile>:r') . '.coll.tim')
call timl#source_file(expand('<sfile>:r') . '.vim.tim')

" vim:set et sw=2:
