import 'package:irc/irc.dart';

class StilesBot extends Bot {
    Client _client;

    Client get client => _client;

    StilesBot(BotConfig config) {
        _client = new Client(config);
    }
}