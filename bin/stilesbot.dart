import 'package:irc/irc.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class StilesBot extends Bot {
    Client _client;
    List<String> channels = [];
    Directory _logLocation;
    Directory _channelLogs;
    Client get client => _client;

    StilesBot(BotConfig config, String logDirectory) {
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
}