import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api/model/model.dart';
import 'api/route/messages.dart';
import 'content.dart';
import 'main.dart';

class MessageList extends StatefulWidget {
  const MessageList({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final List<Message> messages = []; // TODO move state up to store
  bool fetched = false; // TODO this will get more complex

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetch();
  }

  Future<void> _fetch() async {
    final store = PerAccountStoreWidget.of(context);
    final result =
        await getMessages(store.connection, num_before: 100, num_after: 10);
    setState(() {
      messages.addAll(result.messages);
      fetched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!fetched) return const Center(child: CircularProgressIndicator());

    return DefaultTextStyle(
        // TODO figure out text color -- web is supposedly hsl(0deg 0% 20%),
        //   but seems much darker than that
        style: const TextStyle(color: Color.fromRGBO(0, 0, 0, 1)),
        child: ColoredBox(
            color: Colors.white,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildListView(context)))));
  }

  Widget _buildListView(context) {
    return ListView.separated(
        itemCount: messages.length,
        separatorBuilder: (context, i) => const SizedBox(height: 16),
        // Setting reverse: true means the scroll starts at the bottom.
        // Flipping the indexes (in itemBuilder) means the start/bottom
        // has the latest messages.
        // This works great when we want to start from the latest.
        // TODO handle scroll starting at first unread, or link anchor
        reverse: true,
        itemBuilder: (context, i) =>
            MessageItem(message: messages[messages.length - 1 - i]));
  }
}

class MessageItem extends StatelessWidget {
  const MessageItem({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    // TODO recipient headings depend on narrow

    Color recipientColor;
    Widget recipientHeader;
    if (message is StreamMessage) {
      final msg = (message as StreamMessage);
      recipientColor = Colors.black; // TODO get color
      recipientHeader =
          StreamTopicRecipientHeader(message: msg, streamColor: recipientColor);
    } else if (message is PmMessage) {
      final msg = (message as PmMessage);
      recipientColor = Colors.black;
      recipientHeader = PmRecipientHeader(message: msg);
    } else {
      throw Exception("impossible message type: ${message.runtimeType}");
    }

    // TODO fine-tune width of recipient border
    final recipientBorder = BorderSide(color: recipientColor, width: 4);

    return Column(children: [
      recipientHeader,
      DecoratedBox(
          decoration: ShapeDecoration(shape: Border(left: recipientBorder)),
          child: MessageWithSender(message: message)),
    ]);

    // Web handles the left-side recipient marker in a funky way:
    //   box-shadow: inset 3px 0px 0px -1px #c2726a, -1px 0px 0px 0px #c2726a;
    // (where the color is the stream color.)  That is, it's a pair of
    // box shadows.  One of them is inset.
    //
    // At attempt at a literal translation might look like this:
    //
    // DecoratedBox(
    //     decoration: ShapeDecoration(shadows: [
    //       BoxShadow(offset: Offset(3, 0), spreadRadius: -1, color: recipientColor),
    //       BoxShadow(offset: Offset(-1, 0), color: recipientColor),
    //     ], shape: Border.fromBorderSide(BorderSide.none)),
    //     child: MessageWithSender(message: message)),
    //
    // But CSS `box-shadow` seems to not apply under the item itself, while
    // Flutter's BoxShadow does.
  }
}

class StreamTopicRecipientHeader extends StatelessWidget {
  const StreamTopicRecipientHeader(
      {super.key, required this.message, required this.streamColor});

  final StreamMessage message;
  final Color streamColor;

  @override
  Widget build(BuildContext context) {
    final streamName = message.display_recipient; // TODO get from stream data
    final topic = message.subject;
    const contrastingColor = Colors.white; // TODO base on recipientColor
    return Align(
        alignment: Alignment.centerLeft,
        child: RecipientHeaderChevronContainer(
            color: streamColor,
            child: Text("$streamName > $topic", // TODO stream recipient header
                style: const TextStyle(color: contrastingColor))));
  }
}

class PmRecipientHeader extends StatelessWidget {
  const PmRecipientHeader({super.key, required this.message});

  final PmMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
            child: const Text("Private message", // TODO PM recipient headers
                style: TextStyle(color: Colors.white))));
  }
}

/// A widget with the distinctive chevron-tailed shape in Zulip recipient headers.
class RecipientHeaderChevronContainer extends StatelessWidget {
  const RecipientHeaderChevronContainer(
      {super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const chevronLength = 5.0;
    const recipientBorderShape = BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
            topRight: Radius.elliptical(chevronLength, double.infinity),
            bottomRight: Radius.elliptical(chevronLength, double.infinity)));
    return Container(
        decoration: ShapeDecoration(color: color, shape: recipientBorderShape),
        padding: const EdgeInsets.only(right: chevronLength),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 3), child: child));
  }
}

/// A Zulip message, showing the sender's name and avatar.
class MessageWithSender extends StatelessWidget {
  const MessageWithSender({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final avatarUrl = message.avatar_url == null // TODO get from user data
        ? null // TODO handle computing gravatars
        : rewriteImageUrl(message.avatar_url!, store.account);

    final time = _kMessageTimestampFormat
        .format(DateTime.fromMillisecondsSinceEpoch(1000 * message.timestamp));

    // TODO clean up this layout, by less precisely imitating web
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (avatarUrl != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 11, 0),
                child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(4))),
                    width: 35,
                    height: 35,
                    child: Image.network(avatarUrl))),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 3),
                Text(message.sender_full_name, // TODO get from user data
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                MessageContent(message: message),
              ])),
          Container(
              width: 80,
              padding: const EdgeInsets.only(top: 8, right: 10),
              alignment: Alignment.topRight,
              child: Text(time, style: _kMessageTimestampStyle))
        ]));
  }
}

// TODO web seems to ignore locale in formatting time, but we could do better
final _kMessageTimestampFormat = DateFormat('h:m a', 'en_US');

// TODO this seems to come out lighter than on web
final _kMessageTimestampStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: const HSLColor.fromAHSL(0.4, 0, 0, 0.2).toColor());
