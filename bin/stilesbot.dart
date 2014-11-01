import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:irc/irc.dart';
import 'package:json_object/json_object.dart';
import 'package:sqljocky/sqljocky.dart';

typedef CommandHandler(CommandEvent event);

class StilesBot extends Bot {
    Client _client;
    List<String> channels = [];
    Directory _logLocation;
    Directory _channelLogs;

    Map<String, StreamController<CommandEvent>> commands = {};
    CommandHandler commandNotFound = (event) => null;
    String commandPrefix;
    Iterable<String> commandNames() => commands.keys;

    ConnectionPool mysqlPool;

    String nickServPassword;

    Client get client => _client;

    StilesBot() {
        _loadConfig();

        _registerHandlers();
    }

    void _loadConfig() {
        var path = new File.fromUri(Platform.script).parent.path;
        JsonObject config = new JsonObject.fromJsonString(new File("${path}/config.json").readAsStringSync());

        _client = new Client(new BotConfig(
                nickname: config.irc.nickname,
                username: config.irc.username,
                realname: config.irc.realname,
                host: config.irc.host,
                port: config.irc.port
        ));

        _channelLogs = new Directory("${config.logDirectory}/channels");
        if (!_channelLogs.existsSync()) {
            _channelLogs.createSync(recursive: true);
        }
        _logLocation = _channelLogs.parent;

        commandPrefix = config.commandPrefix;

        mysqlPool = new ConnectionPool(
                host: config.mysql.host,
                port: config.mysql.port,
                user: config.mysql.username,
                password: config.mysql.password,
                db: config.mysql.database,
                max: 10
        );

        if (config.containsKey("nickServPassword")) {
            nickServPassword = config.nickServPassword;
        }
    }

    void _registerHandlers() {
        register((ReadyEvent event) {
            if (nickServPassword != null && nickServPassword != "") {
                message("NickServ", "IDENTIFY ${nickServPassword}");
            }
        });

        register((BotJoinEvent event) {
            log("Joined ${event.channel.name}");
        });

        register((BotPartEvent event) {
            log("Left ${event.channel.name}");
        });

        register((JoinEvent event) {
            log("${event.user} joined the channel", channel: event.channel);
        });

        register((PartEvent event) {
            log("${event.user} left the channel", channel: event.channel);
        });

        register((MessageEvent event) {
            var timestamp = new DateFormat('HH:mm:ss').format(new DateTime.now());
            var line = "<${event.from} ${timestamp}> ${event.message}";
            print("[${event.target}]${line}");
            log(line, channel: event.channel);
        });

        register(handleAsCommand);
    }

    void log(String message, {Channel channel}) {
        String dateString = new DateFormat('yyyy-MM-dd').format(new DateTime.now());
        File file;

        if (channel == null) {
            file = new File("${_logLocation.path}/bot_${dateString}.log");
        } else {
            file = new File("${_channelLogs.path}/${channel.name.substring(1)}_${dateString}.log");
        }

        if (file.existsSync()) {
            file.createSync();
        }

        file.writeAsString(message + "\n", mode: FileMode.APPEND);
    }

    void handleAsCommand(MessageEvent event) {
        String message = event.message;

        if (message.startsWith(commandPrefix)) {
            var end = message.contains(" ") ? message.indexOf(" ", commandPrefix.length) : message.length;
            var command = message.substring(commandPrefix.length, end);
            var args = message.substring(end != message.length ? end + 1 : end).split(" ");

            args.removeWhere((arg) => arg.isEmpty || arg == " ");

            if (commands.containsKey(command)) {
                commands[command].add(new CommandEvent(event, command, args));
            } else {
                commandNotFound(new CommandEvent(event, command, args));
            }
        }
    }

    void registerCommand(String name, CommandHandler handler) {
        commands.putIfAbsent(name, () {
            return new StreamController.broadcast();
        }).stream.listen(handler);
    }
}