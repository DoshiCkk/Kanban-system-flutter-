import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Placeholder shapes shown while content loads, so the layout does not
/// jump when it arrives. Pulses unless the platform asks for reduced
/// motion; screen readers hear a single "Loading".
class Skeleton extends StatefulWidget {
  const Skeleton({required this.child, super.key});

  /// Built from [SkeletonBox]es.
  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.commonLoading,
    child: ExcludeSemantics(
      child: FadeTransition(opacity: _pulse, child: widget.child),
    ),
  );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.radius = 8,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Placeholder for lists of avatar + text tiles (workspaces, boards,
/// members).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.itemCount = 5, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _SkeletonTile(index: i),
    ),
  );
}

/// [ListSkeleton] tiles without their own scroll view, for a section of a
/// longer list.
class SkeletonTiles extends StatelessWidget {
  const SkeletonTiles({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SkeletonTile(index: i),
          ),
      ],
    ),
  );
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vary widths so it reads as text, not as bars.
                FractionallySizedBox(
                  widthFactor: index.isEven ? 0.6 : 0.45,
                  child: const SkeletonBox(),
                ),
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  widthFactor: 0.3,
                  child: SkeletonBox(height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Placeholder for the board screen: column tabs and a column of cards.
class BoardSkeleton extends StatelessWidget {
  const BoardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 96, height: 32, radius: 16),
              SizedBox(width: 8),
              SkeletonBox(width: 96, height: 32, radius: 16),
              SizedBox(width: 8),
              SkeletonBox(width: 72, height: 32, radius: 16),
            ],
          ),
          const SizedBox(height: 24),
          for (final height in const [72.0, 96.0, 72.0, 56.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SkeletonBox(height: height, radius: 12),
            ),
        ],
      ),
    ),
  );
}

/// Placeholder for the card screen: title and a few field rows.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FractionallySizedBox(
            widthFactor: 0.7,
            child: SkeletonBox(height: 28),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < 4; i++) ...[
            const Row(
              children: [
                SkeletonBox(width: 24, height: 24, radius: 12),
                SizedBox(width: 16),
                Expanded(child: SkeletonBox()),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const SkeletonBox(height: 96, radius: 12),
        ],
      ),
    ),
  );
}
