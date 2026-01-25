part of 'package:tcg_tracker/main.dart';

class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0B0806),
            Color(0xFF1A120C),
            Color(0xFF2E2217),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: SvgPicture.asset(
                'assets/textures/paper-fibers.svg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: -20,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -30,
            child: Transform.rotate(
              angle: -0.22,
              child: Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 130,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 20,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 70,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            right: 10,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 120,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 360,
            left: 90,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -10,
            child: Transform.rotate(
              angle: -0.38,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.32),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 260,
            left: 140,
            child: Transform.rotate(
              angle: 0.28,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            right: 160,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 260,
            right: 120,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: 95,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 220,
            left: 60,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            right: 10,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 420,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00D97745),
                      Color(0x33D97745),
                      Color(0x00D97745),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -120,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 420,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00E2C26A),
                      Color(0x33E2C26A),
                      Color(0x00E2C26A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
