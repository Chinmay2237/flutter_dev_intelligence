/// Categories of standard Flutter widgets used in AST layout heuristics.
enum WidgetTaxonomyCategory {
  scrollable,
  flexContainer,
  flexItem,
  sliver,
  constraintProvider,
  custom,
}

/// Contextual resolution state of a widget encountered during AST traversal.
enum WidgetResolutionState {
  /// Standard Flutter framework widget with known layout contracts.
  known,

  /// Unknown custom widget; layout contract cannot be inferred purely by name.
  unknown,

  /// Resolved via explicit AST hierarchy or subclass inspection.
  resolved,

  /// Heuristically or partially resolved.
  partiallyResolved,
}

/// Represents the classification result for a widget identifier.
class WidgetClassification {
  const WidgetClassification({
    required this.name,
    required this.category,
    required this.resolutionState,
    this.description,
  });

  final String name;
  final WidgetTaxonomyCategory category;
  final WidgetResolutionState resolutionState;
  final String? description;

  bool get isKnown =>
      resolutionState == WidgetResolutionState.known ||
      resolutionState == WidgetResolutionState.resolved;
  bool get isUnknown => resolutionState == WidgetResolutionState.unknown;
}

/// Centralized taxonomy for known Flutter widget categories.
class WidgetTaxonomy {
  static const Set<String> scrollables = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
    'PageView',
    'NestedScrollView',
    'ReorderableListView',
    'AnimatedList',
    'Scrollable',
    'TabBarView',
    'ListWheelScrollView',
  };

  static const Set<String> flexContainers = <String>{
    'Row',
    'Column',
    'Flex',
    'Wrap',
  };

  static const Set<String> flexItems = <String>{
    'Expanded',
    'Flexible',
    'Spacer',
  };

  static const Set<String> slivers = <String>{
    'SliverList',
    'SliverGrid',
    'SliverFixedExtentList',
    'SliverToBoxAdapter',
    'SliverFillRemaining',
    'SliverPadding',
    'SliverAppBar',
    'SliverPersistentHeader',
    'SliverFillViewport',
    'SliverPrototypeExtentList',
  };

  static const Set<String> constraintProviders = <String>{
    'SizedBox',
    'ConstrainedBox',
    'LimitedBox',
    'UnconstrainedBox',
    'OverflowBox',
    'FractionallySizedBox',
    'AspectRatio',
    'Expanded',
    'Flexible',
    'Align',
    'Center',
  };

  /// Classifies a widget name into standard category and resolution state.
  static WidgetClassification classify(String widgetName) {
    final name = widgetName.contains('.')
        ? widgetName.split('.').last
        : widgetName;

    if (scrollables.contains(name)) {
      return WidgetClassification(
        name: name,
        category: WidgetTaxonomyCategory.scrollable,
        resolutionState: WidgetResolutionState.known,
        description: 'Flutter standard scrollable widget',
      );
    }

    if (flexContainers.contains(name)) {
      return WidgetClassification(
        name: name,
        category: WidgetTaxonomyCategory.flexContainer,
        resolutionState: WidgetResolutionState.known,
        description: 'Flutter standard flex container widget',
      );
    }

    if (flexItems.contains(name)) {
      return WidgetClassification(
        name: name,
        category: WidgetTaxonomyCategory.flexItem,
        resolutionState: WidgetResolutionState.known,
        description: 'Flutter standard flex child item',
      );
    }

    if (slivers.contains(name)) {
      return WidgetClassification(
        name: name,
        category: WidgetTaxonomyCategory.sliver,
        resolutionState: WidgetResolutionState.known,
        description: 'Flutter standard sliver widget',
      );
    }

    if (constraintProviders.contains(name)) {
      return WidgetClassification(
        name: name,
        category: WidgetTaxonomyCategory.constraintProvider,
        resolutionState: WidgetResolutionState.known,
        description: 'Flutter standard constraint provider widget',
      );
    }

    return WidgetClassification(
      name: name,
      category: WidgetTaxonomyCategory.custom,
      resolutionState: WidgetResolutionState.unknown,
      description: 'Custom or unclassified widget',
    );
  }

  static bool isScrollable(String name) => scrollables.contains(name);
  static bool isFlexContainer(String name) => flexContainers.contains(name);
  static bool isFlexItem(String name) => flexItems.contains(name);
  static bool isSliver(String name) => slivers.contains(name);
  static bool isConstraintProvider(String name) =>
      constraintProviders.contains(name);
}
