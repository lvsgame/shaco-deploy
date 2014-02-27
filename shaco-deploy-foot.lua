require "REDIS-LIST"
require "REDIS-VERSION"
require "PASSWORD"

local INFO_PREFIX = "[Shaco-deploy]"
local strfmt = string.format
local os_execute = os.execute

local REDIS_NAME = { "redis-server", "redis-sentinel"}
local SHACO_DEPLOY_MACHINE_DIR="/root"
local SHACO_DEPLOY_MACHINE="shaco-deploy-machine"
local REDIS_MACHINE_FOOT="redis-machine-foot.lua"
local SERVER_MACHINE_FOOT="server-machine-foot"

local REDIS_BIN_DIR_PREFIX="/usr/local"
local REDIS_CONF_DIR_PREFIX="/etc"
local REDIS_BIN_DIR=REDIS_BIN_DIR_PREFIX .. "/bin"
local REDIS_CONF_DIR=REDIS_CONF_DIR_PREFIX .. "/redis"
local USER="root"

local function redis_name(redis_type)
    -- 0: redis-server, 1: redis-sentinel
    return REDIS_NAME[redis_type+1]
end

local function system(shell)
    assert(os_execute(shell))
end

local function myecho(info)
    system(strfmt('echo -e "\\033[40;36;1m%s %s\\033[0m"', INFO_PREFIX, info))
end

local function prepare()
    myecho(strfmt('pack %s ...', SHACO_DEPLOY_MACHINE))
    system(strfmt('mkdir -p %s && \
        cp %s %s && \
        cp -r redis-conf %s && \
        tar -cf %s.tar %s',
        SHACO_DEPLOY_MACHINE,
        REDIS_MACHINE_FOOT, SHACO_DEPLOY_MACHINE,
        SHACO_DEPLOY_MACHINE,
        SHACO_DEPLOY_MACHINE, SHACO_DEPLOY_MACHINE))
    myecho(strfmt('pack %s ok', SHACO_DEPLOY_MACHINE))
end

local function clean()
    system(strfmt('rm -rf %s.tar %s', SHACO_DEPLOY_MACHINE, SHACO_DEPLOY_MACHINE))
end

local function distribute(ip, port, redis_port, redis_type)
    myecho(strfmt('distribute host=%s:%u %s=%u ...', ip, port, redis_name(redis_type), redis_port))
    -- distribute redis-machine-foot && redis sentinel configure
    system(strfmt('expect scp.exp %s %u %s %s %s ./%s.tar', 
        ip, port, USER, PASSWORD, SHACO_DEPLOY_MACHINE_DIR, SHACO_DEPLOY_MACHINE))
    system(strfmt('expect ssh.exp %s %u %s %s "cd %s && \
        tar -xf %s.tar && rm -f %s.tar && \
        mkdir -p %s && \
        cp %s/redis-conf/redis.conf %s && \
        cp %s/redis-conf/redis_%s.conf %s"',
        ip, port, USER, PASSWORD, 
        SHACO_DEPLOY_MACHINE_DIR, SHACO_DEPLOY_MACHINE, SHACO_DEPLOY_MACHINE,
        REDIS_CONF_DIR, 
        SHACO_DEPLOY_MACHINE, REDIS_CONF_DIR,
        SHACO_DEPLOY_MACHINE, redis_port, REDIS_CONF_DIR))
    myecho(strfmt('distribute host=%s:%u %s=%u ok', ip, port, redis_name(redis_type), redis_port))
end

local function operate_redis(ip, port, redis_port, redis_type, redis_op)
    myecho(strfmt('%s [host=%s:%u %s=%u] ...', 
        redis_op, ip, port, redis_name(redis_type), redis_port))
    system(strfmt('expect ssh.exp %s %u %s %s "cd %s/%s && lua %s %s %u %u %s %s %s"', 
        ip, port, USER, PASSWORD, 
        SHACO_DEPLOY_MACHINE_DIR, SHACO_DEPLOY_MACHINE, REDIS_MACHINE_FOOT,
        redis_op, redis_port, redis_type, 
        REDIS_BIN_DIR_PREFIX, REDIS_CONF_DIR_PREFIX, REDIS_VERSION))
    myecho(strfmt('%s [host=%s:%u %s=%u] ok', 
        redis_op, ip, port, redis_name(redis_type), redis_port))
end

local function execute(command, op)
    for i, one in ipairs(REDIS_LIST) do
        command(one[1], one[2], one[3], one[4], op)
    end
end

local USAGE="Usage: shaco-deploy-foot.lua [redis] [distribute] [[install] [start] [stop]"
local arg = {...}
if #arg < 2 then
    print(USAGE)
    return 1
end

if arg[1] == "redis" then
    if arg[2] == "distribute" then
        prepare()
        execute(distribute)
        clean()
    else
        execute(operate_redis, arg[2])
    end
else
    print(USAGE)
end
