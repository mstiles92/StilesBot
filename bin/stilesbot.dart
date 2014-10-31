import 'package:irc/irc.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';

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

    Client get client => _client;

    StilesBot(BotConfig config, {String logDirectory: "logs", this.commandPrefix: "!"}) {
        _client = new Client(config);
        _logLocation = new Directory(logDirectory);
        _channelLogs = new Directory("${logDirectory}/channels");
        if (!_channelLogs.existsSync()) {
            _channelLogs.create(recursive: true);
        }
        _logLocation = _channelLogs.parent;

        _registerHandlers();
    }

    void _registerHandlers() {
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
            var line = "<${event.from}> ${event.message}";
            print("<${event.target}>${line}");
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