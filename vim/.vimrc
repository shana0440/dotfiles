if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source ~/.vimrc
endif

call plug#begin('~/.vim/plugged')
Plug 'sainnhe/edge'
Plug 'airblade/vim-gitgutter'
Plug 'brooth/far.vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'sheerun/vim-polyglot'
Plug 'terryma/vim-multiple-cursors'
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'preservim/nerdcommenter'
Plug 'w0rp/ale'
Plug 'vim-airline/vim-airline'
call plug#end()

set number
set wildmenu
set autoread

set autoindent
set backspace=2
set shiftwidth=2
set softtabstop=2

set smartcase
set ignorecase
set hlsearch
set incsearch

set list
set listchars=tab:›\ ,trail:•,extends:#,nbsp:.

set undofile
set undodir=~/.vim/undodir
set undolevels=1000
set undoreload=10000

"set clipboard+=unnamed

let $FZF_DEFAULT_COMMAND = 'ag --hidden --ignore .git -g ""'
map <C-p> :FZF<CR>

map <C-m> <Plug>NERDCommenterToggle

map <C-e> :NERDTreeToggle<CR>

if exists('+termguicolors')
	let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
	let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
	set termguicolors
endif

set background=dark

" the configuration options should be placed before `colorscheme edge`
let g:edge_style = 'neon'
let g:edge_disable_italic_comment = 1

colorscheme edge


cab W  w
cab Wq wq
cab wQ wq
cab WQ wq
cab Q  q

set omnifunc=ale#completion#OmniFunc
let g:ale_fix_on_save = 1
let g:ale_fixers = {
\   'css': ['prettier'],
\   'dart': ['dartfmt'],
\   'javascript': ['prettier'],
\   'markdown': ['prettier'],
\   'python': ['black', 'isort'],
\   'scss': ['prettier'],
\   'sh': ['shfmt'],
\   'typescript': ['prettier'],
\   'typescriptreact': ['prettier'],
\}
let g:ale_linters = {
\   'dart': ['language_server'],
\   'python': ['mypy', 'pyls'],
\}
let g:ale_linter_aliases = {
\   'typescriptreact': 'typescript'
\}

map <F2> :ALEGoToDefinition<CR>
map <F1> :ALEDetail<CR>
