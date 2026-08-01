import 'package:flutter/material.dart';

class SpinIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool spinning;
  final VoidCallback onPressed;

  const SpinIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.spinning,
    required this.onPressed,
  });

  @override
  State<SpinIconButton> createState() => _SpinIconButtonState();
}

class _SpinIconButtonState extends State<SpinIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(SpinIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _controller.repeat();
    } else if (!widget.spinning && oldWidget.spinning) {
      _finishTurn();
    }
  }

  void _finishTurn() {
    if (!_controller.isAnimating) return;
    _controller.stop();
    _controller.animateTo(1, curve: Curves.easeOut).then((_) {
      if (mounted) _controller.reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: () {
        if (!_controller.isAnimating) {
          _controller.forward(from: 0).then((_) {
            if (mounted && !widget.spinning) _controller.reset();
          });
        }
        widget.onPressed();
      },
      icon: RotationTransition(
        turns: _controller,
        child: Icon(widget.icon),
      ),
    );
  }
}

class BouncyIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const BouncyIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<BouncyIconButton> createState() => _BouncyIconButtonState();
}

class _BouncyIconButtonState extends State<BouncyIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    lowerBound: 0.72,
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bounce() async {
    await _controller.reverse();
    if (!mounted) return;
    await _controller.animateTo(1, curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: () {
          _bounce();
          widget.onPressed();
        },
        icon: Icon(widget.icon),
      ),
    );
  }
}

class StatusPingDot extends StatefulWidget {
  final Color color;
  final bool pinging;

  const StatusPingDot({super.key, required this.color, required this.pinging});

  @override
  State<StatusPingDot> createState() => _StatusPingDotState();
}

class _StatusPingDotState extends State<StatusPingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pinging) _controller.repeat();
  }

  @override
  void didUpdateWidget(StatusPingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinging && !oldWidget.pinging) {
      _controller.repeat();
    } else if (!widget.pinging && oldWidget.pinging) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pinging)
                Container(
                  width: 6 + 10 * t,
                  height: 6 + 10 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 1 - t),
                      width: 1.5,
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
