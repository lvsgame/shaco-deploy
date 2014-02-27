local INFO_PREFIX="[Redis]"
local strfmt = string.format
local strmatch = string.match
local os_execute = os.execute

local REDIS_NAMES = { "redis-server", "redis-sentinel"}

local USAGE="Usage: redis-machine-foot.lua [install] [start] [stop] \
redis_port redis_type redis_bin_dir_prefix redis_conf_dir_prefix redis_version"
local arg = {...}
if #arg < 6 then
    print(USAGE)
    return 1
end

local CMD=arg[1]
local REDIS_PORT=arg[2]
local REDIS_TYPE=arg[3]
local REDIS_BIN_DIR_PREFIX=arg[4]
local REDIS_CONF_DIR_PREFIX=arg[5]
--REDIS_BIN_DIR_PREFIX=/usr/local
--REDIS_CONF_DIR_PREFIX=/etc
local REDIS_VERSION=arg[6]
local REDIS_BIN_DIR=REDIS_BIN_DIR_PREFIX .. "/bin"
local REDIS_CONF_DIR=REDIS_CONF_DIR_PREFIX .. "/redis"
local REDIS_PACKAGE="redis-" .. REDIS_VERSION
local REDIS_NAME=REDIS_NAMES[REDIS_TYPE+1]

local function system(shell)
    assert(os_execute(shell))
end

local function myecho(info)
    system(strfmt('echo "\\033[40;32;1m%s %s\\033[0m"', INFO_PREFIX, info))
end

local function is_installed()
    local f = io.popen("redis-server --version", "r")    
    local result = f:read("*a")
    if strmatch("redis-server --version", "v=(%d+.%d+.%d+)") == REDIS_VERSION then
        return 1
    else
        return 0
    end
end

local function force_install()
    myecho('install %s ...', REDIS_PACKAGE)
    system(strfmt('cd /tmp && \
        rm -f  %s.tar.gz && \
        rm -rf %s && \
        wget http://download.redis.io/releases/%s.tar.gz && \
        tar -xf %s.tar.gz && \
        cd %s && \
        make && make PREFIX=%s install',
        REDIS_PACKAGE, REDIS_PACKAGE, REDIS_PACKAGE, REDIS_PACKAGE, 
        REDIS_PACKAGE, REDIS_BIN_DIR_PREFIX))
    myecho('install %s ok', REDIS_PACKAGE)
end

local function install()
    if is_installed() then
        myecho(strfmt('%s already install', REDIS_PACKAGE))
    else
        force_install()
    end
end

local function start()
    myecho(strfmt('start %s ...', REDIS_NAME))
    if REDIS_TYPE == 0 then
        system(strfmt('%s/%s %s/redis_%s.conf', 
        REDIS_BIN_DIR, REDIS_NAME, REDIS_CONF_DIR, REDIS_PORT))
    else
        system(strfmt('%s/%s %s/redis_%s.conf -- sentinel', 
        REDIS_BIN_DIR, REDIS_NAME, REDIS_CONF_DIR, REDIS_PORT))
    end
    myecho(strfmt('start %s ok', REDIS_NAME))
end

local function stop()
    myecho(strfmt('stop %s ...', REDIS_NAME))
    system(strfmt('%s/redis-cli -p %u shutdown', REDIS_BIN_DIR, REDIS_PORT))
    myecho(strfmt('stop %s ok', REDIS_NAME))
end

local COMMAND_MAP = {
    install = install,
    start = start,
    stop = stop,
}

local command = COMMAND_MAP[CMD]
if command then
    command()
else
    print(USAGE)
end
