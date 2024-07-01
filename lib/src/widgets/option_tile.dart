import 'package:cake_wallet/themes/extensions/option_tile_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.onPressed,
    required this.imagePath,
    required this.title,
    this.leftSubTitle,
    this.rightSubTitle,
    this.description,
    this.firstBadgeName,
    this.secondBadgeName,
    this.borderRadius,
    this.padding,
    this.titleTextStyle,
    this.leftSubTitleMaxLines,
    this.leftSubTitleTextStyle,
    this.leadingIcon,
    this.isSelected = false,
  });

  final VoidCallback onPressed;
  final String imagePath;
  final String title;
  final String? leftSubTitle;
  final String? rightSubTitle;
  final String? description;
  final String? firstBadgeName;
  final String? secondBadgeName;
  final double? borderRadius;
  final EdgeInsets? padding;
  final TextStyle? titleTextStyle;
  final int? leftSubTitleMaxLines;
  final TextStyle? leftSubTitleTextStyle;
  final IconData? leadingIcon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? Theme.of(context).extension<OptionTileTheme>()!.titleColor
        : Theme.of(context).cardColor;

    final titleColor = isSelected
        ? Theme.of(context).cardColor
        : Theme.of(context).extension<OptionTileTheme>()!.titleColor;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: padding ?? EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius ?? 12)),
          color: backgroundColor,
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                getImage(imagePath),
                SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: titleTextStyle ??
                                    TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: titleColor,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            if (firstBadgeName != null)
                              Badge(
                                title: firstBadgeName!,
                                textColor: backgroundColor,
                                backgroundColor: titleColor,
                              ),
                            if (secondBadgeName != null)
                              Badge(
                                title: secondBadgeName!,
                                textColor: backgroundColor,
                                backgroundColor: titleColor,
                              ),
                            if (leadingIcon != null)
                              Icon(
                                leadingIcon,
                                size: 16,
                                color: titleColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (leftSubTitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      leftSubTitle!,
                      maxLines: leftSubTitleMaxLines,
                      style: leftSubTitleTextStyle ??
                          TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: titleColor,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (rightSubTitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      rightSubTitle!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: titleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            if (description != null)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: titleColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  Badge({required this.textColor, required this.backgroundColor, required this.title});

  final String title;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Container(
        height: 30,
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.5)), color: backgroundColor),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Widget getImage(String imagePath) {
  final bool isNetworkImage = imagePath.startsWith('http') || imagePath.startsWith('https');
  final bool isSvg = imagePath.endsWith('.svg');

  if (isNetworkImage) {
    return isSvg
        ? SvgPicture.network(
            imagePath,
            height: 35,
            width: 35,
            placeholderBuilder: (BuildContext context) => Container(
              height: 35,
              width: 35,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          )
        : Image.network(
            imagePath,
            height: 35,
            width: 35,
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                height: 35,
                width: 35,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
              return Container(
                height: 35,
                width: 35,
              );
            },
          );
  } else {
    return isSvg
        ? SvgPicture.asset(imagePath, height: 35, width: 35)
        : Image.asset(imagePath, height: 35, width: 35);
  }
}
