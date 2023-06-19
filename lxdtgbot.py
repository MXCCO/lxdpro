#!/usr/bin/env python3
# pylint: disable=unused-argument, wrong-import-position
# This program is dedicated to the public domain under the CC0 license.

import os, logging, subprocess, random, string, time, sys

from telegram import __version__ as TG_VER

try:
    from telegram import __version_info__
except ImportError:
    __version_info__ = (0, 0, 0, 0, 0)  # type: ignore[assignment]

if __version_info__ < (20, 0, 0, "alpha", 1):
    raise RuntimeError(
        f"This example is not compatible with your current PTB version {TG_VER}. To view the "
        f"{TG_VER} version of this example, "
        f"visit https://docs.python-telegram-bot.org/en/v{TG_VER}/examples.html"
    )
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update, ForceReply
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
    ConversationHandler,
    MessageHandler,
    filters
    
)
BOTID = sys.argv[1]
BOTAPI = sys.argv[2]
# Enable logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)
# Stages
START_ROUTES, END_ROUTES = range(2)
# Callback data
ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGIT, NINE, TEN, ELEVEN = range(11)
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Send message on `/start`."""
    user = update.message.from_user
    dddw = str(user.id)
    logger.info("User %s started the conversation.", user.id)
    
    keyboard = [
        [   
            InlineKeyboardButton("创建服务器", callback_data=str(ONE)),
            InlineKeyboardButton("管理服务器", callback_data=str(TWO)),
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    if dddw != BOTID : 
        await update.message.reply_text("非授权用户禁止操作")
        return
    await update.message.reply_text("用户id: %s\n欢迎使用LXD管理机器人"%dddw, reply_markup=reply_markup)
    return START_ROUTES 



async def three(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Prompt same text & keyboard as `start` does but not as new message"""
    dddw = update.callback_query.from_user.id
    query = update.callback_query
    await query.answer()
    keyboard = [
        [
            InlineKeyboardButton("创建服务器", callback_data=str(ONE)),
            InlineKeyboardButton("管理服务器", callback_data=str(TWO)),
            
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(text="用户id: %s\n欢迎使用LXD管理机器人"%dddw, reply_markup=reply_markup)
    return START_ROUTES


async def one(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.answer()
    keyboard = [
        [
            InlineKeyboardButton("创建1C128M", callback_data=str(FOUR)),
            InlineKeyboardButton("创建1C256M", callback_data=str(FIVE)),
        ],
        [
            InlineKeyboardButton("创建1C512M", callback_data=str(TEN)),
            InlineKeyboardButton("创建1C1G", callback_data=str(ELEVEN)),
        ],
        [
            InlineKeyboardButton("更多配置请使用脚本开", callback_data=str(THREE)),
        ],
        [
            InlineKeyboardButton("返回首页", callback_data=str(THREE)),
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(
        text="服务器创建页面,配置默认3G的硬盘", reply_markup=reply_markup
    )
    return START_ROUTES


async def two(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    niuzi = os.popen('lxc ls -c ns -f csv').read().split('\n')[:-1]
    new_niuzi = [item.replace(',', ' 状态: ').replace('RUNNING', '正在运行').replace('STOPPED', '关机') for item in niuzi]
    # niuzi2 = os.popen('lxc ls -c s -f csv').read().split('\n')[:-1]
    query = update.callback_query
    await query.answer()
    keyboard = []
    bi = ""
    for ddad in new_niuzi:
        gg = "\n服务器ID : %s "%ddad
        bi = bi + gg
        # print(gg)
        # gg=[InlineKeyboardButton("服务器ID: %s"%ddad, callback_data=str(ONE)), ]
        # bi = "".join(str("服务器ID :%s"%ddad))
    keyboard.append([InlineKeyboardButton("返回主页", callback_data=str(THREE)),])
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(
        # text="服务器管理页面\n 你牛逼", reply_markup=reply_markup
        text="%s\n\n请输出 /cp 实例ID 进行管理实例"%bi, reply_markup=reply_markup
    )
    print(query.edit_message_text)
    return START_ROUTES


# async def three(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
#     """Show new choice of buttons. This is the end point of the conversation."""
#     query = update.callback_query
#     await query.answer()
#     keyboard = [
#         [
#             InlineKeyboardButton("Yes, let's do it again!", callback_data=str(ONE)),
#             InlineKeyboardButton("Nah, I've had enough ...", callback_data=str(TWO)),
#         ]
#     ]
#     reply_markup = InlineKeyboardMarkup(keyboard)
#     await query.edit_message_text(
#         text="Third CallbackQueryHandler. Do want to start over?", reply_markup=reply_markup
#     )
#     # Transfer to conversation state `SECOND`
#     return END_ROUTES

#创建实例1C128M
async def four(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(text="开始为你创建,请稍等......")
    ran_str = ''.join(random.sample(string.ascii_letters, 6))
    if  subprocess.getstatusoutput("lxc network create %s"%ran_str)[0] != 0 : return 
    await query.edit_message_text(text="进度:\n[███                 ] 20%\n网络创建成功,创建硬盘中.....")
    if subprocess.getstatusoutput("lxc storage create %s btrfs"%ran_str)[0] != 0 : return
    time.sleep(5)
    await query.edit_message_text(text="进度:\n[████████            ] 40%\n硬盘创建成功,创建实例中.....")
    lxc_start=subprocess.getstatusoutput("lxc init images:debian/11 %s -n %s -s %s"%(ran_str,ran_str,ran_str))
    if lxc_start[0] != 0 : 
        await query.edit_message_text(text="实例创建失败:\n%s"%lxc_start[1])
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        return
    await query.edit_message_text(text="进度:\n[██████████          ] 60%\n实例创建成功,开始配置实例....")
    if subprocess.getstatusoutput("lxc config set %s limits.cpu 1"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████    ] 70%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config set %s limits.memory 128MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[███████████████████ ] 80%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config device set %s root size=3072MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████████] 100%\n实例创建完成,正在为你开机.....")
    subprocess.getstatusoutput("lxc start %s"%ran_str)
    lxc_info = subprocess.getstatusoutput("lxc info %s"%ran_str)
    await query.edit_message_text(
        text="容器名ID: %s\n实例信息\n%s"%(ran_str,lxc_info[1])
    )
    return START_ROUTES

#创建1C256M
async def five(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(text="开始为你创建,请稍等......")
    ran_str = ''.join(random.sample(string.ascii_letters, 6))
    if  subprocess.getstatusoutput("lxc network create %s"%ran_str)[0] != 0 : return 
    await query.edit_message_text(text="进度:\n[███                 ] 20%\n网络创建成功,创建硬盘中.....")
    if subprocess.getstatusoutput("lxc storage create %s btrfs"%ran_str)[0] != 0 : return
    time.sleep(5)
    await query.edit_message_text(text="进度:\n[████████            ] 40%\n硬盘创建成功,创建实例中.....")
    lxc_start=subprocess.getstatusoutput("lxc init images:debian/11 %s -n %s -s %s"%(ran_str,ran_str,ran_str))
    if lxc_start[0] != 0 : 
        await query.edit_message_text(text="实例创建失败:\n%s"%lxc_start[1])
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        return
    await query.edit_message_text(text="进度:\n[██████████          ] 60%\n实例创建成功,开始配置实例....")
    if subprocess.getstatusoutput("lxc config set %s limits.cpu 1"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████    ] 70%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config set %s limits.memory 256MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[███████████████████ ] 80%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config device set %s root size=3072MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████████] 100%\n实例创建完成,正在为你开机.....")
    subprocess.getstatusoutput("lxc start %s"%ran_str)
    lxc_info = subprocess.getstatusoutput("lxc info %s"%ran_str)
    await query.edit_message_text(
        text="容器名ID: %s\n实例信息\n%s"%(ran_str,lxc_info[1])
    )
    return START_ROUTES




#创建实例1C512M
async def ten(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(text="开始为你创建,请稍等......")
    ran_str = ''.join(random.sample(string.ascii_letters, 6))
    if  subprocess.getstatusoutput("lxc network create %s"%ran_str)[0] != 0 : return 
    await query.edit_message_text(text="进度:\n[███                 ] 20%\n网络创建成功,创建硬盘中.....")
    if subprocess.getstatusoutput("lxc storage create %s btrfs"%ran_str)[0] != 0 : return
    time.sleep(5)
    await query.edit_message_text(text="进度:\n[████████            ] 40%\n硬盘创建成功,创建实例中.....")
    lxc_start=subprocess.getstatusoutput("lxc init images:debian/11 %s -n %s -s %s"%(ran_str,ran_str,ran_str))
    if lxc_start[0] != 0 : 
        await query.edit_message_text(text="实例创建失败:\n%s"%lxc_start[1])
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        return
    await query.edit_message_text(text="进度:\n[████████████        ] 60%\n实例创建成功,开始配置实例....")
    if subprocess.getstatusoutput("lxc config set %s limits.cpu 1"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████    ] 70%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config set %s limits.memory 512MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[██████████████████  ] 80%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config device set %s root size=3072MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████████] 100%\n实例创建完成,正在为你开机.....")
    subprocess.getstatusoutput("lxc start %s"%ran_str)
    lxc_info = subprocess.getstatusoutput("lxc info %s"%ran_str)
    await query.edit_message_text(
        text="容器名ID: %s\n实例信息\n%s"%(ran_str,lxc_info[1])
    )
    return START_ROUTES

#创建1C1G
async def eleven(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(text="开始为你创建,请稍等......")
    ran_str = ''.join(random.sample(string.ascii_letters, 6))
    if  subprocess.getstatusoutput("lxc network create %s"%ran_str)[0] != 0 : return 
    await query.edit_message_text(text="进度:\n[███                 ] 20%\n网络创建成功,创建硬盘中.....")
    if subprocess.getstatusoutput("lxc storage create %s btrfs"%ran_str)[0] != 0 : return
    time.sleep(5)
    await query.edit_message_text(text="进度:\n[████████            ] 40%\n硬盘创建成功,创建实例中.....")
    lxc_start=subprocess.getstatusoutput("lxc init images:debian/11 %s -n %s -s %s"%(ran_str,ran_str,ran_str))
    if lxc_start[0] != 0 : 
        await query.edit_message_text(text="实例创建失败:\n%s"%lxc_start[1])
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        subprocess.getstatusoutput("lxc storage delete %s btrfs"%ran_str)
        return
    await query.edit_message_text(text="进度:\n[██████████          ] 60%\n实例创建成功,开始配置实例....")
    if subprocess.getstatusoutput("lxc config set %s limits.cpu 1"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████    ] 70%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config set %s limits.memory 1024MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[███████████████████ ] 80%\n正在配置实例")
    if subprocess.getstatusoutput("lxc config device set %s root size=3072MB"%ran_str)[0] != 0 : return
    await query.edit_message_text(text="进度:\n[████████████████████] 100%\n实例创建完成,正在为你开机.....")
    subprocess.getstatusoutput("lxc start %s"%ran_str)
    lxc_info = subprocess.getstatusoutput("lxc info %s"%ran_str)
    await query.edit_message_text(
        text="容器名ID: %s\n实例信息\n%s"%(ran_str,lxc_info[1])
    )
    return START_ROUTES




async def end(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Returns `ConversationHandler.END`, which tells the
    ConversationHandler that the conversation is over.
    """
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(text="See you next time!")
    return ConversationHandler.END



#查询实例
async def hhhee(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    dddw = str(update.message.from_user.id)
    global lxc_n
    lxc_n=update.message.text[4:]
    keyboard = [
        [InlineKeyboardButton("启动服务器", callback_data=str(SIX)),],
        [InlineKeyboardButton("暂停服务器", callback_data=str(SEVEN)),],
        [InlineKeyboardButton("删除服务器", callback_data=str(EIGIT)),],
        [InlineKeyboardButton("服务器信息", callback_data=str(NINE)),],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    if dddw != BOTID : 
        await update.message.reply_text("非授权用户禁止操作")
        return
    if lxc_n != "" :
        await update.message.reply_text(
        text="正在查询实例...."
    ) 
        niuzi = os.popen('lxc ls -c n -f csv').read().split('\n')[:-1]
        if (niuzi.count("%s"%lxc_n)) == 0 : 
            await update.message.reply_text(
            text="没有这个实例"
    )   
        else :
            await update.message.reply_text(
            "当前服务器为: %s"%lxc_n
            ,reply_markup=reply_markup,)
    else:
        await update.message.reply_text(
        "未填写服务器名称！请使用请使用 /cp 实例ID"
        ,)
    # print(update.message.text[4:])
    return START_ROUTES

#启动实例
async def six(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.edit_message_text(
        text="正在启动实例,请稍等...."
    )
    # lxc_start = os.popen('lxc start %s'%lxc_n).read()
    lxc_start = subprocess.getstatusoutput("lxc start %s"%lxc_n)
    
    if lxc_start[0] == 0  :
        await query.edit_message_text(
        text="实例启动成功"
    )
    elif (lxc_start[1].find("Error: The instance is already running")) == 0 :
        await query.edit_message_text(
        text="实例正在运行"
    )
    else:
        await query.edit_message_text(
        text="实例启动失败"
    )
        await context.bot.answer_callback_query(
        callback_query_id = query.id, text = "启动失败原因", show_alert = True
        
    )
    return START_ROUTES

#停止实例
async def seven(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.edit_message_text(
        text="正在停止实例,请稍等...."
    )
    lxc_stop = subprocess.getstatusoutput("lxc stop %s"%lxc_n)
    
    if lxc_stop[0] == 0  :
        await query.edit_message_text(
        text="实例停止成功"
    )
    elif (lxc_stop[1].find("Error: The instance is already stopped")) == 0 :
        await query.edit_message_text(
        text="当前实例已处于停止状态"
    )
    else:
        await query.edit_message_text(
        text="实例停止失败"
    )
        await context.bot.answer_callback_query(
        callback_query_id = query.id, text = "失败原因:\n%s"%lxc_stop[1], show_alert = True
        
    )
    return START_ROUTES


#删除实例
async def eigit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.edit_message_text(
        text="开始删除实例....."
    )
    lxc_dele_1 = subprocess.getstatusoutput("lxc delete %s"%lxc_n)
    
    if lxc_dele_1[0] == 0  :
        await query.edit_message_text(
        text="实例删除成功"
    )
    # elif (lxc_dele_1[1].find("Error: The instance is already stopped")) == 0 :
    #     await query.edit_message_text(
    #     text="当前实例已处于停止状态"
    # )
    else:
        await query.edit_message_text(
        text="实例删除失败"
    )
        await context.bot.answer_callback_query(
        callback_query_id = query.id, text = "失败原因:\n%s"%lxc_dele_1[1], show_alert = True
        
    )
        return START_ROUTES
    
    # await query.edit_message_text(
    #     text="正在删除实例配置文件....."
    # )
    # lxc_dele_2 = subprocess.getstatusoutput("lxc profile delete %s"%lxc_n)
    
    # if lxc_dele_2[0] == 0  :
    #     await query.edit_message_text(
    #     text="实例配置文件删除成功"
    # )
    # # elif (lxc_dele_2[1].find("Error: The instance is already stopped")) == 0 :
    # #     await query.edit_message_text(
    # #     text="当前实例已处于停止状态"
    # # )
    # else:
    #     await query.edit_message_text(
    #     text="实例配置文件删除失败,实力未完全删除"
    # )
    #     await context.bot.answer_callback_query(
    #     callback_query_id = query.id, text = "失败原因:\n%s"%lxc_dele_2[1], show_alert = True
        
    # )
    #     return START_ROUTES



    await query.edit_message_text(
        text="正在删除实例硬盘....."
    )
    lxc_dele_3 = subprocess.getstatusoutput("lxc storage delete %s"%lxc_n)
    
    if lxc_dele_3[0] == 0  :
        await query.edit_message_text(
        text="实例硬盘删除成功"
    )
    # elif (lxc_start[1].find("Error: The instance is already stopped")) == 0 :
    #     await query.edit_message_text(
    #     text="当前实例已处于停止状态"
    # )
    else:
        await query.edit_message_text(
        text="实例硬盘删除失败,实例未完全删除"
    )
        await context.bot.answer_callback_query(
        callback_query_id = query.id, text = "失败原因:\n%s"%lxc_dele_3[1], show_alert = True
        
    )
        return START_ROUTES



    await query.edit_message_text(
        text="正在删除实例网络....."
    )
    lxc_dele_4 = subprocess.getstatusoutput("lxc network delete %s"%lxc_n)
    
    if lxc_dele_4[0] == 0  :
        await query.edit_message_text(
        text="实例网络删除成功"
    )
    # elif (lxc_start[1].find("Error: The instance is already stopped")) == 0 :
    #     await query.edit_message_text(
    #     text="当前实例已处于停止状态"
    # )
    else:
        await query.edit_message_text(
        text="实例网络删除失败,实例未完全删除"
    )
        await context.bot.answer_callback_query(
        callback_query_id = query.id, text = "失败原因:\n%s"%lxc_dele_4[1], show_alert = True
        
    )
        
        return START_ROUTES
    
    
    await query.edit_message_text(
        text="实例已完全删除"
    )
    
    #     await context.bot.answer_callback_query(
    #     callback_query_id = query.id, text = "停止失败原因", show_alert = True
        
    # )
    return START_ROUTES

async def nine(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show new choice of buttons"""
    query = update.callback_query
    await query.edit_message_text(
        text="正在查询中,请稍等....."
    )
    lxc_info = subprocess.getstatusoutput("lxc info %s"%lxc_n)
    await query.edit_message_text(
        text="实例信息\n%s"%lxc_info[1]
    )
    # await context.bot.answer_callback_query(
    #     callback_query_id = query.id, text = "实例信息%s"%lxc_info[1], show_alert = True
        
    # )
    return START_ROUTES

async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    # print(update.message.text)
    await update.message.reply_text("这是一个LXD管理机器人请使用 /start 和 /cp 进行操作管理")
    return
def main() -> None:
    """Run the bot."""
    # Create the Application and pass it your bot's token.
    application = Application.builder().token("%s"%BOTAPI).build()
# 5351558085:AAFGhgUYWH9WyNci1FEQo2Y1CF79W9_tt1Q
    # Setup conversation handler with the states FIRST and SECOND
    # Use the pattern parameter to pass CallbackQueries with specific
    # data pattern to the corresponding handlers.
    # ^ means "start of line/string"
    # $ means "end of line/string"
    # So ^ABC$ will only allow 'ABC'
    conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            START_ROUTES: [
                CallbackQueryHandler(one, pattern="^" + str(ONE) + "$"),
                CallbackQueryHandler(two, pattern="^" + str(TWO) + "$"),
                CallbackQueryHandler(three, pattern="^" + str(THREE) + "$"),
                CallbackQueryHandler(four, pattern="^" + str(FOUR) + "$"),
                CallbackQueryHandler(five, pattern="^" + str(FIVE) + "$"),
                CallbackQueryHandler(ten, pattern="^" + str(TEN) + "$"),
                CallbackQueryHandler(eleven, pattern="^" + str(ELEVEN) + "$"),
                # CallbackQueryHandler(start_over, pattern="^" + str(FIVE) + "$"),
            ],
            END_ROUTES: [
                # CallbackQueryHandler(start_over, pattern="^" + str(ONE) + "$"),
                CallbackQueryHandler(end, pattern="^" + str(TWO) + "$"),
            ],
        },
        fallbacks=[CommandHandler("start", start)],
    )
    
    lxcss = ConversationHandler(
        entry_points=[CommandHandler("cp", hhhee)],
        states={
            START_ROUTES: [
                CallbackQueryHandler(six, pattern="^" + str(SIX) + "$"),
                CallbackQueryHandler(seven, pattern="^" + str(SEVEN) + "$"),
                CallbackQueryHandler(eigit, pattern="^" + str(EIGIT) + "$"),
                CallbackQueryHandler(nine, pattern="^" + str(NINE) + "$"),
                # CallbackQueryHandler(start_over, pattern="^" + str(FIVE) + "$"),
            ],
            END_ROUTES: [
                # CallbackQueryHandler(start_over, pattern="^" + str(ONE) + "$"),
                CallbackQueryHandler(end, pattern="^" + str(TWO) + "$"),
            ],
        },
        fallbacks=[CommandHandler("cp", hhhee)],
    )
    application.add_handler(conv_handler)
    application.add_handler(lxcss)
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))
    application.run_polling()

if __name__ == "__main__":
    main()
