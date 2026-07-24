import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBarSimple extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  AppBarSimple({this.title = "UTHM Share A Ride"});
  @override
  Widget build(BuildContext context) {
    return AppBar(
      foregroundColor: Colors.white,
      backgroundColor: Color.fromARGB(255, 54, 87, 118),
      title: Text(
        title,
        style: GoogleFonts.inriaSans(
            color: Colors.white,
            fontStyle: FontStyle.normal,
            fontSize: 20,),
      ),
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(AppBar().preferredSize.height);
}
