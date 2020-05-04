import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/nodes/widgets/node_indicator.dart';
import 'package:cake_wallet/src/stores/node_list/node_list_store.dart';
import 'package:cake_wallet/src/stores/settings/settings_store.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/nodes/widgets/node_list_row.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';

class NodeListPage extends BasePage {
  NodeListPage();

  @override
  String get title => S.current.nodes;

  @override
  Color get backgroundColor => PaletteDark.historyPanel;

  @override
  Widget trailing(context) {
    final nodeList = Provider.of<NodeListStore>(context);
    final settings = Provider.of<SettingsStore>(context);

    return Container(
      height: 32,
      width: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        color: PaletteDark.menuList
      ),
      child: ButtonTheme(
        minWidth: double.minPositive,
        child: FlatButton(
            onPressed: () async {
              await showDialog<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertWithTwoActions(
                      alertTitle: S.of(context).node_reset_settings_title,
                      alertContent: S.of(context).nodes_list_reset_to_default_message,
                      leftButtonText: S.of(context).reset,
                      rightButtonText: S.of(context).cancel,
                      actionLeftButton: () async {
                        Navigator.of(context).pop();
                        await nodeList.reset();
                        await settings.setCurrentNodeToDefault();
                      },
                      actionRightButton: () => Navigator.of(context).pop()
                    );
                  });
            },
            child: Text(
              S.of(context).reset,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10.0,
                  color: Colors.blue),
            )),
      ),
    );
  }

  @override
  Widget body(context) => NodeListPageBody();
}

class NodeListPageBody extends StatefulWidget {
  @override
  NodeListPageBodyState createState() => NodeListPageBodyState();
}

class NodeListPageBodyState extends State<NodeListPageBody> {
  @override
  Widget build(BuildContext context) {
    final nodeList = Provider.of<NodeListStore>(context);
    final settings = Provider.of<SettingsStore>(context);

    final trashImage = Image.asset('assets/images/trash.png', height: 32, width: 32, color: Colors.white);

    final currentColor = PaletteDark.menuHeader;
    final notCurrentColor = PaletteDark.menuList;

    final currentTextColor = Colors.blue;
    final notCurrentTextColor = Colors.white;

    return Container(
      height: double.infinity,
      color: PaletteDark.historyPanel,
      padding: EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          NodeListRow(
              title: S.of(context).add_new_node,
              trailing: Icon(Icons.add, color: Colors.white, size: 24.0),
              color: PaletteDark.menuList,
              textColor: Colors.white,
              onTap: () async =>
              await Navigator.of(context).pushNamed(Routes.newNode),
              isDrawTop: true,
              isDrawBottom: true),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Observer(
                builder: (_) => ListView.separated(
                    separatorBuilder: (_, __) => Container(
                      height: 1,
                      padding: EdgeInsets.only(left: 24),
                      color: PaletteDark.menuList,
                      child: Container(
                        height: 1,
                        color: PaletteDark.walletCardTopEndSync,
                      ),
                    ),
                    itemCount: nodeList.nodes.length,
                    itemBuilder: (BuildContext context, int index) {
                      final node = nodeList.nodes[index];

                      final isDrawTop = index == 0 ? true : false;
                      final isDrawBottom = index == nodeList.nodes.length - 1 ? true : false;

                      return Observer(
                        builder: (_) {
                          final isCurrent = settings.node == null
                              ? false
                              : node.key == settings.node.key;

                          final content = NodeListRow(
                              title: node.uri,
                              trailing: FutureBuilder(
                                  future: nodeList.isNodeOnline(node),
                                  builder: (context, snapshot) {
                                    switch (snapshot.connectionState) {
                                      case ConnectionState.done:
                                        return NodeIndicator(
                                            color: snapshot.data as bool
                                                ? Palette.green
                                                : Palette.red);
                                      default:
                                        return NodeIndicator();
                                    }
                                  }),
                              color: isCurrent ? currentColor : notCurrentColor,
                              textColor: isCurrent ? currentTextColor : notCurrentTextColor,
                              onTap: () async {
                                if (!isCurrent) {
                                  await showDialog<void>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertWithTwoActions(
                                            alertTitle: S.current.nodes,
                                            alertContent:  S.of(context)
                                                .change_current_node(node.uri),
                                            leftButtonText: S.of(context).change,
                                            rightButtonText: S.of(context).cancel,
                                            actionLeftButton: () async {
                                              Navigator.of(context).pop();
                                              await settings.setCurrentNode(
                                                  node: node);
                                            },
                                            actionRightButton: () => Navigator.of(context).pop()
                                        );
                                      });
                                }
                              },
                              isDrawTop: isDrawTop,
                              isDrawBottom: isDrawBottom);

                          return isCurrent
                              ? content
                              : Dismissible(
                              key: Key('${node.key}'),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertWithTwoActions(
                                          alertTitle: S.of(context).remove_node,
                                          alertContent: S.of(context).remove_node_message,
                                          leftButtonText: S.of(context).remove,
                                          rightButtonText: S.of(context).cancel,
                                          actionLeftButton: () =>
                                              Navigator.pop(context, true),
                                          actionRightButton: () =>
                                              Navigator.pop(context, false)
                                      );
                                    });
                              },
                              onDismissed: (direction) async =>
                              await nodeList.remove(node: node),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                  padding: EdgeInsets.only(right: 10.0, top: 2),
                                  alignment: AlignmentDirectional.centerEnd,
                                  color: Palette.red,
                                  child: Column(
                                    children: <Widget>[
                                      trashImage,
                                      Text(
                                        S.of(context).delete,
                                        style: TextStyle(color: Colors.white),
                                      )
                                    ],
                                  )),
                              child: content);
                        },
                      );
                    })
              ),
            )
          )
        ],
      ),
    );
  }
}
