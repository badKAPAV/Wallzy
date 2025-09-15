import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MyIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: SvgPicture.asset(
        'assets/icons/my_icon.svg',
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSurface, // follows Material 3 theme
          BlendMode.srcIn,
        ),
        width: 24,
        height: 24,
      ),
    );
  }
}
