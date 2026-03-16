import 'package:flutter/material.dart';

class EnergyBar extends StatelessWidget {
  final int energy;
  final int maxEnergy;
  final int ticket;
  final int maxTicket;

  const EnergyBar({
    super.key,
    required this.energy,
    required this.maxEnergy,
    required this.ticket,
    required this.maxTicket,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 375;
    final size = MediaQuery.of(context).size;
    final titleFontSize = (size.width * 0.038).clamp(14.0, 18.0);

    double progress = energy / maxEnergy;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [

          /// Thunder icon
          Image.asset(
            "assets/images/item/energy.png",
            width: 10 * scale,
          ),

          SizedBox(width: 4 * scale),

          /// Energy number
          Text(
            "$energy",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),

          SizedBox(width: 8 * scale),

          /// Energy progress bar
          Expanded(
            child: Container(
              height: 12 * scale,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF7ED957),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: 10 * scale),

          /// Ticket icon
          Image.asset(
            "assets/images/item/Ticket_energy_img.png",
            width: 22 * scale,
          ),

          SizedBox(width: 4 * scale),

          /// Ticket counter
          Text(
            "$ticket/$maxTicket",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
        ],
      ),
    );
  }
}