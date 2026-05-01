import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models.dart';
import '../state/app_controller.dart';
import '../theme.dart';

const double keliDesktopBreakpoint = 1100;

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (controller.isBootstrapping) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!controller.isAuthenticated) {
          return const LoginScreen();
        }

        final isDesktop = constraints.maxWidth >= keliDesktopBreakpoint;
        final body =
            _PageBody(page: controller.selectedPage, isDesktop: isDesktop);

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                const _SideNavigation(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFBFCFE), keliSurface],
                      ),
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: keliSurface,
          body: SafeArea(
            bottom: false,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFBFCFE), keliSurface],
                ),
              ),
              child: body,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            height: 66,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: controller.selectedPage,
            onDestinationSelected: controller.selectPage,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.power_settings_new), label: '首页'),
              NavigationDestination(
                  icon: Icon(Icons.hub_outlined), label: '节点'),
              NavigationDestination(
                  icon: Icon(Icons.storefront_outlined), label: '商店'),
              NavigationDestination(icon: Icon(Icons.tune), label: '设置'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined), label: '日志'),
            ],
          ),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final panelController = TextEditingController(text: 'https://sp.huhu.icu');
  final apiPathController = TextEditingController(text: '/api/v1');
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;

  @override
  void dispose() {
    panelController.dispose();
    apiPathController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: KeliCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: keliBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keli Client',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          Text('登录你的面板账号', style: TextStyle(color: keliMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: panelController,
                    decoration: const InputDecoration(
                      labelText: '面板地址',
                      hintText: 'https://example.com',
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiPathController,
                    decoration: const InputDecoration(
                      labelText: 'API 路径',
                      hintText: '/api/v1',
                      prefixIcon: Icon(Icons.route_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    onSubmitted: (_) => _submit(controller),
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(showPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                    ),
                  ),
                  if (controller.lastError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(controller.lastError!,
                          style: const TextStyle(color: keliRed)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: controller.isLoggingIn
                          ? null
                          : () => _submit(controller),
                      icon: controller.isLoggingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: Text(controller.isLoggingIn ? '登录中' : '登录'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(AppController controller) {
    controller.login(
      baseUrl: panelController.text,
      apiPrefix: apiPathController.text,
      email: emailController.text,
      password: passwordController.text,
    );
  }
}

class _PageBody extends StatefulWidget {
  const _PageBody({
    required this.page,
    required this.isDesktop,
  });

  final int page;
  final bool isDesktop;

  @override
  State<_PageBody> createState() => _PageBodyState();
}

class _PageBodyState extends State<_PageBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _PageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (widget.page) {
      0 => HomeScreen(isDesktop: widget.isDesktop),
      1 => NodesScreen(isDesktop: widget.isDesktop),
      2 => const StoreScreen(),
      3 => const SettingsScreen(),
      _ => const LogsScreen(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = widget.isDesktop ? 20.0 : 12.0;
        final topPadding = widget.isDesktop ? 12.0 : 10.0;
        final bottomPadding = widget.isDesktop ? 8.0 : 12.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final maxContentWidth = widget.isDesktop ? 1040.0 : 720.0;
        final contentWidth =
            availableWidth > maxContentWidth ? maxContentWidth : availableWidth;
        final fillViewport = widget.isDesktop && widget.page == 0;
        final contentHeight =
            (constraints.maxHeight - topPadding - bottomPadding)
                .clamp(0.0, double.infinity)
                .toDouble();
        final content = Center(
          child: SizedBox(
            width: contentWidth < 0 ? 0 : contentWidth,
            child: child,
          ),
        );

        if (fillViewport) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              bottomPadding,
            ),
            child: Center(
              child: SizedBox(
                width: contentWidth < 0 ? 0 : contentWidth,
                height: contentHeight,
                child: child,
              ),
            ),
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          primary: false,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                bottomPadding,
              ),
              sliver: SliverToBoxAdapter(child: content),
            ),
          ],
        );
      },
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation();

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return Container(
      width: 138,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: keliLine)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: keliBlueStrong,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text('K',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Keli Client',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _NavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  label: '首页',
                  selected: controller.selectedPage == 0),
              _NavItem(
                  index: 1,
                  icon: Icons.hub_outlined,
                  label: '节点',
                  selected: controller.selectedPage == 1),
              _NavItem(
                  index: 2,
                  icon: Icons.storefront_outlined,
                  label: '商店',
                  selected: controller.selectedPage == 2),
              _NavItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  label: '设置',
                  selected: controller.selectedPage == 3),
              _NavItem(
                  index: 4,
                  icon: Icons.article_outlined,
                  label: '日志',
                  selected: controller.selectedPage == 4),
              const Spacer(),
              const _VersionBlock(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => controller.selectPage(index),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? keliBlueStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: keliBlueStrong.withValues(alpha: 0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : keliInk),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : keliInk,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionBlock extends StatelessWidget {
  const _VersionBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusDot(color: keliGreen),
            SizedBox(width: 5),
            Text('v0.1.16',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: 4),
        Text('当前版本', style: TextStyle(color: keliMuted, fontSize: 11)),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final profile = controller.profile;
    final node = controller.selectedNode;

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileHeader(),
          const SizedBox(height: 12),
          _AccountPanel(profile: profile, compact: true),
          const SizedBox(height: 12),
          _ConnectPanel(node: node, compact: true),
          const SizedBox(height: 12),
          const _MobileModeStrip(),
          const SizedBox(height: 12),
          _RuntimeStrip(isDesktop: false),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DesktopAccountBar(profile: profile),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 8,
                child: Column(
                  children: [
                    Expanded(
                      child: _ConnectPanel(node: node, fillHeight: true),
                    ),
                    const SizedBox(height: 12),
                    _RuntimeStrip(isDesktop: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _CurrentNodePanel(node: node),
                    const SizedBox(height: 12),
                    const Expanded(
                      child: _ModeAndRoutePanel(fillHeight: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopAccountBar extends StatelessWidget {
  const _DesktopAccountBar({required this.profile});

  final AppProfile? profile;

  @override
  Widget build(BuildContext context) {
    final expire = profile == null ? '-' : dateText(profile!.expireAt);
    final total = profile == null
        ? '-'
        : '${profile!.totalTrafficGb.toStringAsFixed(2)} GB';
    final remaining =
        profile == null ? '-' : profile!.remainingTrafficGb.toStringAsFixed(2);
    final daysLeft = profile == null ? '-' : daysLeftText(profile!.expireAt);
    final email = profile?.email ?? '未登录';
    final accountMeta = profile == null ? '套餐: -' : profileMetaText(profile!);
    return KeliCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: keliBlueSoft,
                      child: Text(profileInitials(profile),
                          style: const TextStyle(
                              color: keliBlueStrong,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                  child: Text(email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              const SizedBox(width: 8),
                              _MiniBadge(
                                  text: subscriptionBadgeText(profile),
                                  color: subscriptionBadgeColor(profile)),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(accountMeta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: keliMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('剩余流量',
                        style: TextStyle(color: keliMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: remaining,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900)),
                          TextSpan(
                              text: ' GB / $total',
                              style: const TextStyle(
                                  color: keliMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: profile?.usageRatio ?? 0,
                        color: keliBlueStrong,
                        backgroundColor: const Color(0xFFE8EDF5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('到期时间',
                        style: TextStyle(color: keliMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(expire,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(daysLeft,
                        style: const TextStyle(color: keliMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return Row(
      children: [
        const Expanded(
            child: Text('Keli Client',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        IconButton(
          tooltip: '刷新',
          onPressed: controller.isBootstrapping ? null : controller.bootstrap,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _ConnectPanel extends StatelessWidget {
  const _ConnectPanel({
    required this.node,
    this.compact = false,
    this.fillHeight = false,
  });

  final ProxyNode? node;
  final bool compact;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final connected =
        controller.connectionState == ConnectionStateKind.connected;
    final busy = controller.connectionState == ConnectionStateKind.connecting ||
        controller.connectionState == ConnectionStateKind.reconnecting;
    final statusColor = switch (controller.connectionState) {
      ConnectionStateKind.connected => keliGreen,
      ConnectionStateKind.connecting => keliOrange,
      ConnectionStateKind.reconnecting => keliOrange,
      ConnectionStateKind.error => keliRed,
      ConnectionStateKind.disconnected => keliBlue,
    };
    final statusText = switch (controller.connectionState) {
      ConnectionStateKind.connected => '已连接',
      ConnectionStateKind.connecting => '连接中',
      ConnectionStateKind.reconnecting => '重连中',
      ConnectionStateKind.error => '连接异常',
      ConnectionStateKind.disconnected => '未连接',
    };

    final duration = controller.stats.duration;
    final durationText = durationClockText(duration);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final tightPhone = compact && screenWidth < 430;
    final dialOuter = compact ? (tightPhone ? 154.0 : 168.0) : 184.0;
    final dialMiddle = compact ? dialOuter - 18 : 166.0;
    final dialInner = compact ? dialOuter - 56 : 128.0;

    return KeliCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: SizedBox(
        height: compact || fillHeight ? null : 356,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (compact)
              Row(
                children: [
                  const Expanded(
                    child: Text('连接状态',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  _MiniBadge(
                    text: node?.protocol ?? '未选择',
                    color: connected ? keliGreen : keliMuted,
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Expanded(
                    child: Text('连接状态',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  _MiniBadge(
                    text: node?.protocol ?? '未选择',
                    color: connected ? keliGreen : keliMuted,
                  ),
                ],
              ),
            if (compact) const SizedBox(height: 12),
            if (!compact) const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: busy
                  ? null
                  : connected
                      ? controller.disconnect
                      : controller.connect,
              child: SizedBox(
                width: dialOuter,
                height: dialOuter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: dialOuter,
                      height: dialOuter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: connected
                              ? const [
                                  Color(0xFF18C6B5),
                                  Color(0xFF32D583),
                                  Color(0xFF18C6B5)
                                ]
                              : [
                                  statusColor,
                                  statusColor.withValues(alpha: 0.42),
                                  statusColor
                                ],
                        ),
                      ),
                    ),
                    Container(
                      width: dialMiddle,
                      height: dialMiddle,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFD),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: dialInner,
                      height: dialInner,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: connected
                                  ? const Color(0xFF18C6B5)
                                  : statusColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              connected
                                  ? Icons.shield_outlined
                                  : Icons.power_settings_new,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: compact ? 18 : 21,
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(durationText,
                              style: const TextStyle(
                                  color: keliMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: compact ? double.infinity : 178,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : connected
                        ? controller.disconnect
                        : controller.connect,
                icon: Icon(
                    connected ? Icons.link_off : Icons.play_arrow_rounded,
                    size: 18),
                label: Text(connected ? '断开连接' : '立即连接'),
              ),
            ),
            if (compact && node != null) ...[
              const SizedBox(height: 14),
              _SelectedNodeCard(node: node!),
            ],
            if (!compact) const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SelectedNodeCard extends StatelessWidget {
  const _SelectedNodeCard({required this.node});

  final ProxyNode node;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showNodePickerDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: keliLineSoft),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _NodeFlagIcon(node: node, selected: true, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(node.protocol,
                        style: const TextStyle(color: keliMuted, fontSize: 12)),
                  ],
                ),
              ),
              const _MiniBadge(text: '更换', color: keliGreen),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: keliMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePickerActionButton extends StatelessWidget {
  const _NodePickerActionButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return SizedBox(
      width: compact ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: controller.isTestingLatency || controller.nodes.isEmpty
            ? null
            : controller.testAllLatency,
        icon: controller.isTestingLatency
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.speed_outlined, size: 17),
        label: Text(controller.isTestingLatency ? '测速中' : '批量测速'),
      ),
    );
  }
}

enum _NodeFlag {
  australia,
  canada,
  china,
  france,
  germany,
  hongKong,
  japan,
  netherlands,
  singapore,
  southKorea,
  taiwan,
  unitedKingdom,
  unitedStates,
}

class _NodeFlagIcon extends StatelessWidget {
  const _NodeFlagIcon({
    required this.node,
    this.selected = false,
    this.size = 34,
  });

  final ProxyNode? node;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final flag = _nodeFlag(node);
    final radius = BorderRadius.circular(size * 0.27);
    if (flag == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? keliBlueStrong : const Color(0xFFF2F5F9),
          borderRadius: radius,
        ),
        child: Icon(
          Icons.public,
          color: selected ? Colors.white : keliMuted,
          size: size * 0.55,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(
          color:
              selected ? keliBlueStrong.withValues(alpha: 0.32) : keliLineSoft,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: keliBlueStrong.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.20),
        child: CustomPaint(
          painter: _NodeFlagPainter(flag),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _NodeFlagPainter extends CustomPainter {
  const _NodeFlagPainter(this.flag);

  final _NodeFlag flag;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;

    void fill(Color color, [Rect? target]) {
      paint
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRect(target ?? rect, paint);
    }

    void horizontalStripes(List<Color> colors) {
      final stripeHeight = size.height / colors.length;
      for (var i = 0; i < colors.length; i += 1) {
        fill(
          colors[i],
          Rect.fromLTWH(0, stripeHeight * i, size.width, stripeHeight),
        );
      }
    }

    void verticalStripes(List<Color> colors) {
      final stripeWidth = size.width / colors.length;
      for (var i = 0; i < colors.length; i += 1) {
        fill(
          colors[i],
          Rect.fromLTWH(stripeWidth * i, 0, stripeWidth, size.height),
        );
      }
    }

    switch (flag) {
      case _NodeFlag.japan:
        fill(Colors.white);
        paint.color = const Color(0xFFBC002D);
        canvas.drawCircle(
            size.center(Offset.zero), size.shortestSide * 0.27, paint);
      case _NodeFlag.unitedStates:
        final stripeHeight = size.height / 13;
        fill(Colors.white);
        for (var i = 0; i < 13; i += 2) {
          fill(
            const Color(0xFFB22234),
            Rect.fromLTWH(0, stripeHeight * i, size.width, stripeHeight),
          );
        }
        fill(
          const Color(0xFF3C3B6E),
          Rect.fromLTWH(0, 0, size.width * 0.48, stripeHeight * 7),
        );
        paint.color = Colors.white;
        for (var y = 0; y < 4; y += 1) {
          for (var x = 0; x < 5; x += 1) {
            canvas.drawCircle(
              Offset(size.width * (0.08 + x * 0.08),
                  size.height * (0.08 + y * 0.11)),
              size.shortestSide * 0.018,
              paint,
            );
          }
        }
      case _NodeFlag.singapore:
        fill(Colors.white);
        fill(
          const Color(0xFFEF3340),
          Rect.fromLTWH(0, 0, size.width, size.height / 2),
        );
        paint.color = Colors.white;
        canvas.drawCircle(
          Offset(size.width * 0.30, size.height * 0.25),
          size.shortestSide * 0.13,
          paint,
        );
        paint.color = const Color(0xFFEF3340);
        canvas.drawCircle(
          Offset(size.width * 0.35, size.height * 0.25),
          size.shortestSide * 0.11,
          paint,
        );
        paint.color = Colors.white;
        for (var i = 0; i < 5; i += 1) {
          canvas.drawCircle(
            Offset(
              size.width * (0.47 + (i % 2) * 0.06),
              size.height * (0.14 + i * 0.045),
            ),
            size.shortestSide * 0.018,
            paint,
          );
        }
      case _NodeFlag.germany:
        horizontalStripes(
          const [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)],
        );
      case _NodeFlag.netherlands:
        horizontalStripes(
          const [Color(0xFFAE1C28), Colors.white, Color(0xFF21468B)],
        );
      case _NodeFlag.hongKong:
        fill(const Color(0xFFDE2910));
        paint.color = Colors.white;
        final center = size.center(Offset.zero);
        for (var i = 0; i < 5; i += 1) {
          final angle = (-90 + i * 72) * 3.141592653589793 / 180;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                center.dx + size.width * 0.16 * math.cos(angle),
                center.dy + size.height * 0.16 * math.sin(angle),
              ),
              width: size.width * 0.18,
              height: size.height * 0.08,
            ),
            paint,
          );
        }
      case _NodeFlag.taiwan:
        fill(const Color(0xFFFE0000));
        fill(
          const Color(0xFF000095),
          Rect.fromLTWH(0, 0, size.width * 0.56, size.height * 0.58),
        );
        paint.color = Colors.white;
        canvas.drawCircle(
          Offset(size.width * 0.28, size.height * 0.29),
          size.shortestSide * 0.12,
          paint,
        );
      case _NodeFlag.china:
        fill(const Color(0xFFDE2910));
        paint.color = const Color(0xFFFFDE00);
        canvas.drawCircle(
          Offset(size.width * 0.27, size.height * 0.28),
          size.shortestSide * 0.09,
          paint,
        );
        for (final offset in const [
          Offset(0.43, 0.16),
          Offset(0.51, 0.28),
          Offset(0.50, 0.42),
          Offset(0.40, 0.52),
        ]) {
          canvas.drawCircle(
            Offset(size.width * offset.dx, size.height * offset.dy),
            size.shortestSide * 0.035,
            paint,
          );
        }
      case _NodeFlag.unitedKingdom:
        fill(const Color(0xFF012169));
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..color = Colors.white
          ..strokeWidth = size.shortestSide * 0.20;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        paint
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = size.shortestSide * 0.09;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        paint
          ..color = Colors.white
          ..strokeWidth = size.shortestSide * 0.24;
        canvas.drawLine(Offset(size.width / 2, 0),
            Offset(size.width / 2, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 2),
            Offset(size.width, size.height / 2), paint);
        paint
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = size.shortestSide * 0.13;
        canvas.drawLine(Offset(size.width / 2, 0),
            Offset(size.width / 2, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 2),
            Offset(size.width, size.height / 2), paint);
      case _NodeFlag.france:
        verticalStripes(
          const [Color(0xFF002654), Colors.white, Color(0xFFED2939)],
        );
      case _NodeFlag.southKorea:
        fill(Colors.white);
        paint.color = const Color(0xFFCD2E3A);
        canvas.drawCircle(
          Offset(size.width * 0.50, size.height * 0.43),
          size.shortestSide * 0.16,
          paint,
        );
        paint.color = const Color(0xFF0047A0);
        canvas.drawCircle(
          Offset(size.width * 0.50, size.height * 0.57),
          size.shortestSide * 0.16,
          paint,
        );
      case _NodeFlag.canada:
        verticalStripes(
          const [Color(0xFFFF0000), Colors.white, Color(0xFFFF0000)],
        );
        paint.color = const Color(0xFFFF0000);
        final path = Path()
          ..moveTo(size.width * 0.50, size.height * 0.23)
          ..lineTo(size.width * 0.59, size.height * 0.43)
          ..lineTo(size.width * 0.70, size.height * 0.39)
          ..lineTo(size.width * 0.62, size.height * 0.55)
          ..lineTo(size.width * 0.70, size.height * 0.63)
          ..lineTo(size.width * 0.55, size.height * 0.64)
          ..lineTo(size.width * 0.50, size.height * 0.78)
          ..lineTo(size.width * 0.45, size.height * 0.64)
          ..lineTo(size.width * 0.30, size.height * 0.63)
          ..lineTo(size.width * 0.38, size.height * 0.55)
          ..lineTo(size.width * 0.30, size.height * 0.39)
          ..lineTo(size.width * 0.41, size.height * 0.43)
          ..close();
        canvas.drawPath(path, paint);
      case _NodeFlag.australia:
        fill(const Color(0xFF012169));
        paint.color = Colors.white;
        for (final offset in const [
          Offset(0.68, 0.25),
          Offset(0.78, 0.45),
          Offset(0.62, 0.65),
          Offset(0.83, 0.72),
        ]) {
          canvas.drawCircle(
            Offset(size.width * offset.dx, size.height * offset.dy),
            size.shortestSide * 0.035,
            paint,
          );
        }
        fill(Colors.white,
            Rect.fromLTWH(0, 0, size.width * 0.48, size.height * 0.12));
        fill(Colors.white,
            Rect.fromLTWH(0, 0, size.width * 0.12, size.height * 0.48));
        fill(const Color(0xFFC8102E),
            Rect.fromLTWH(0, 0, size.width * 0.48, size.height * 0.06));
        fill(const Color(0xFFC8102E),
            Rect.fromLTWH(0, 0, size.width * 0.06, size.height * 0.48));
    }
  }

  @override
  bool shouldRepaint(covariant _NodeFlagPainter oldDelegate) {
    return oldDelegate.flag != flag;
  }
}

_NodeFlag? _nodeFlag(ProxyNode? node) {
  final raw = node?.name.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final lower = raw.toLowerCase();

  bool hasText(List<String> values) {
    return values.any(raw.contains);
  }

  bool hasWord(List<String> values) {
    return values.any((value) {
      final escaped = RegExp.escape(value.toLowerCase());
      return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(lower);
    });
  }

  if (hasText(['中国香港', '香港']) || hasWord(['hong kong', 'hk', 'hkg'])) {
    return _NodeFlag.hongKong;
  }
  if (hasText(['台湾', '台灣']) || hasWord(['taiwan', 'tw', 'twn'])) {
    return _NodeFlag.taiwan;
  }
  if (hasText(['日本', '东京', '東京', '大阪']) ||
      hasWord(['japan', 'jp', 'jpn', 'tokyo', 'osaka'])) {
    return _NodeFlag.japan;
  }
  if (hasText(
          ['美国', '美國', '洛杉矶', '洛杉磯', '纽约', '紐約', '西雅图', '聖荷西', '圣何塞', '硅谷']) ||
      hasWord([
        'united states',
        'america',
        'usa',
        'us',
        'lax',
        'los angeles',
        'new york',
        'seattle',
        'sanjose',
        'san jose',
      ])) {
    return _NodeFlag.unitedStates;
  }
  if (hasText(['新加坡']) || hasWord(['singapore', 'sg', 'sin'])) {
    return _NodeFlag.singapore;
  }
  if (hasText(['德国', '德國', '法兰克福', '法蘭克福']) ||
      hasWord(['germany', 'de', 'deu', 'bayern', 'frankfurt'])) {
    return _NodeFlag.germany;
  }
  if (hasText(['荷兰', '荷蘭']) ||
      hasWord(['netherlands', 'holland', 'nl', 'ams', 'amsterdam'])) {
    return _NodeFlag.netherlands;
  }
  if (hasText(['英国', '英國', '伦敦', '倫敦']) ||
      hasWord(['united kingdom', 'england', 'uk', 'gb', 'london'])) {
    return _NodeFlag.unitedKingdom;
  }
  if (hasText(['法国', '法國', '巴黎']) || hasWord(['france', 'fr', 'paris'])) {
    return _NodeFlag.france;
  }
  if (hasText(['韩国', '韓國', '首尔', '首爾']) ||
      hasWord(['south korea', 'korea', 'kr', 'kor', 'seoul'])) {
    return _NodeFlag.southKorea;
  }
  if (hasText(['加拿大', '多伦多', '多倫多', '温哥华', '溫哥華']) ||
      hasWord(['canada', 'ca', 'toronto', 'vancouver'])) {
    return _NodeFlag.canada;
  }
  if (hasText(['澳大利亚', '澳大利亞', '澳洲', '悉尼', '雪梨']) ||
      hasWord(['australia', 'au', 'sydney'])) {
    return _NodeFlag.australia;
  }
  if (hasText(['中国', '中國', '大陆', '大陸']) ||
      hasWord(['china', 'cn', 'mainland'])) {
    return _NodeFlag.china;
  }

  return null;
}

class _CurrentNodePanel extends StatelessWidget {
  const _CurrentNodePanel({required this.node});

  final ProxyNode? node;

  @override
  Widget build(BuildContext context) {
    final n = node;
    final controller = AppControllerScope.of(context);
    return KeliCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('当前节点',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900))),
              _MiniBadge(
                text: n?.isOnline == true ? '在线' : '离线',
                color: n?.isOnline == true ? keliGreen : keliRed,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: keliBlueSoft,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showNodePickerDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD8E8FF)),
                ),
                child: Row(
                  children: [
                    _NodeFlagIcon(node: n, selected: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n?.name ?? '未选择节点',
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(n?.protocol ?? '-',
                              style: const TextStyle(
                                  color: keliMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more_rounded,
                        color: keliBlueStrong, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _NodeStatCell(label: '协议', value: n?.protocol ?? '-')),
              const SizedBox(width: 8),
              Expanded(
                  child: _NodeStatCell(
                      label: '延迟',
                      value: nodeLatencyText(controller, n),
                      color: nodeLatencyStatusColor(controller, n))),
              const SizedBox(width: 8),
              Expanded(
                  child: _NodeStatCell(
                      label: '倍率',
                      value:
                          n == null ? '-' : '${n.rate.toStringAsFixed(1)}x')),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: keliLineSoft),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.swap_horiz_rounded,
                  title: '更换',
                  onTap: () => showNodePickerDialog(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.speed_outlined,
                  title: controller.isTestingLatency ? '测速中' : '测速',
                  onTap: controller.isTestingLatency || n == null
                      ? null
                      : controller.testSelectedNodeLatency,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.article_outlined,
                  title: '日志',
                  onTap: () => controller.selectPage(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showNodePickerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _NodePickerDialog(),
  );
}

class _NodePickerDialog extends StatefulWidget {
  const _NodePickerDialog();

  @override
  State<_NodePickerDialog> createState() => _NodePickerDialogState();
}

class _NodePickerDialogState extends State<_NodePickerDialog> {
  String query = '';
  bool autoLatencyQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (autoLatencyQueued) {
      return;
    }
    autoLatencyQueued = true;
    Future<void>.microtask(() {
      if (mounted) {
        return AppControllerScope.of(context).autoTestLatencyOnNodeListOpen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.width < 520;
    final normalizedQuery = query.trim().toLowerCase();
    final nodes = controller.nodes.where((node) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return node.name.toLowerCase().contains(normalizedQuery) ||
          node.protocol.toLowerCase().contains(normalizedQuery) ||
          node.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
    }).toList();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 24,
        vertical: compact ? 10 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? screenSize.width : 560,
          maxHeight: compact ? screenSize.height * 0.9 : 620,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 18,
            compact ? 14 : 18,
            compact ? 14 : 18,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text('选择节点',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _NodePickerActionButton(compact: true),
              ] else
                Row(
                  children: [
                    const Expanded(
                      child: Text('选择节点',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    const _NodePickerActionButton(compact: false),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索节点、协议或标签',
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: nodes.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('没有匹配的节点',
                              style: TextStyle(color: keliMuted)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: nodes.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: keliLineSoft),
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          final selected = controller.selectedNodeId == node.id;
                          return _NodePickerRow(
                            node: node,
                            selected: selected,
                            onTap: () async {
                              await controller.selectNode(node);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePickerRow extends StatelessWidget {
  const _NodePickerRow({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final ProxyNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final latencyColor = nodeLatencyStatusColor(controller, node);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _NodeFlagIcon(node: node, selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(node.protocol,
                          style:
                              const TextStyle(color: keliMuted, fontSize: 12)),
                      Text('${node.rate.toStringAsFixed(1)}x',
                          style:
                              const TextStyle(color: keliMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 74,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                nodeLatencyText(controller, node),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: latencyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? keliBlueStrong : keliMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeStatCell extends StatelessWidget {
  const _NodeStatCell({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: keliLineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: keliMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? keliInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ModeAndRoutePanel extends StatelessWidget {
  const _ModeAndRoutePanel({this.fillHeight = false});

  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return KeliCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('代理模式',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          ModeToggleLine(
            icon: Icons.monitor_outlined,
            title: '系统代理',
            value: controller.proxyMode == ProxyMode.system,
            onChanged: (_) => controller.selectMode(ProxyMode.system),
          ),
          const SizedBox(height: 6),
          ModeToggleLine(
            icon: Icons.shield_outlined,
            title: 'TUN模式',
            value: controller.proxyMode == ProxyMode.tun,
            onChanged: (_) => controller.selectMode(ProxyMode.tun),
          ),
          const SizedBox(height: 10),
          _ModeSummaryStrip(mode: controller.proxyMode),
          if (fillHeight) const Spacer() else const SizedBox(height: 9),
          const Divider(height: 1),
          const SizedBox(height: 7),
          const Text('分流设置',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const DetailLine(label: '路由规则', value: '跟随配置'),
          const DetailLine(label: '局域网规则', value: '跟随配置'),
          const DetailLine(label: 'DNS', value: '跟随配置'),
        ],
      ),
    );
  }
}

class _ModeSummaryStrip extends StatelessWidget {
  const _ModeSummaryStrip({required this.mode});

  final ProxyMode mode;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      ProxyMode.tun => '当前使用 TUN 模式',
      ProxyMode.vpn => '当前使用 VPN 模式',
      ProxyMode.system => '当前使用系统代理',
    };
    final description = switch (mode) {
      ProxyMode.tun => '通过虚拟网卡接管更多应用流量。',
      ProxyMode.vpn => '移动端 VPN 模式由系统网络层接管。',
      ProxyMode.system => '浏览器和常规应用会跟随系统代理设置。',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: keliBlueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.route_outlined,
                color: keliBlueStrong, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: keliMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileModeStrip extends StatelessWidget {
  const _MobileModeStrip();

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return KeliCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: _CompactModeButton(
              icon: Icons.monitor_outlined,
              title: '系统代理',
              selected: controller.proxyMode == ProxyMode.system,
              onTap: () => controller.selectMode(ProxyMode.system),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactModeButton(
              icon: Icons.shield_outlined,
              title: 'TUN模式',
              selected: controller.proxyMode == ProxyMode.tun,
              onTap: () => controller.selectMode(ProxyMode.tun),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactModeButton extends StatelessWidget {
  const _CompactModeButton({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? keliBlueSoft : const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? const Color(0xFFD8E8FF) : keliLineSoft),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? keliBlueStrong : keliMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              width: 28,
              height: 16,
              decoration: BoxDecoration(
                color: selected ? keliBlueStrong : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment:
                  selected ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.all(2),
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: keliLineSoft),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: enabled ? keliMuted : keliMuted.withValues(alpha: 0.55)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: enabled ? keliInk : keliMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.profile, this.compact = false});

  final AppProfile? profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return KeliCard(child: SizedBox(height: compact ? 128 : 260));
    }
    final expire = dateText(profile!.expireAt);
    if (compact) {
      return KeliCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: keliBlueSoft,
                  child: Text(profileInitials(profile),
                      style: const TextStyle(
                          color: keliBlueStrong, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile!.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(profile!.planName,
                          style:
                              const TextStyle(color: keliMuted, fontSize: 12)),
                    ],
                  ),
                ),
                _MiniBadge(
                    text: subscriptionBadgeText(profile),
                    color: subscriptionBadgeColor(profile)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(profile!.remainingTrafficGb.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(width: 5),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('GB 剩余',
                      style: TextStyle(color: keliMuted, fontSize: 12)),
                ),
                const Spacer(),
                Text(expire,
                    style: const TextStyle(
                        color: keliMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: profile!.usageRatio,
                backgroundColor: const Color(0xFFE8EDF5),
                color: keliBlueStrong,
              ),
            ),
          ],
        ),
      );
    }

    return KeliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('订阅状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(profile!.email, style: const TextStyle(color: keliMuted)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${profile!.remainingTrafficGb.toStringAsFixed(1)} GB',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('剩余流量', style: TextStyle(color: keliMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: profile!.usageRatio,
              backgroundColor: const Color(0xFFE5E7EB),
              color: keliBlueStrong,
            ),
          ),
          const SizedBox(height: 20),
          _MetricGrid(
            items: [
              MetricItem(label: '套餐', value: profile!.planName),
              MetricItem(label: '到期', value: expire),
              MetricItem(
                  label: '已用',
                  value: '${profile!.usedTrafficGb.toStringAsFixed(1)} GB'),
              MetricItem(label: '重置', value: profileResetText(profile!)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuntimeStrip extends StatelessWidget {
  const _RuntimeStrip({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final duration = controller.stats.duration;
    final durationText = durationClockText(duration);
    final items = [
      _RuntimeMetricData(
          label: '下载速度',
          value: controller.stats.downloadSpeed,
          icon: Icons.south_rounded,
          color: keliGreen),
      _RuntimeMetricData(
          label: '上传速度',
          value: controller.stats.uploadSpeed,
          icon: Icons.north_rounded,
          color: keliBlueStrong),
      _RuntimeMetricData(
          label: '本次用量',
          value: controller.stats.sessionTraffic,
          icon: Icons.donut_large_rounded,
          color: const Color(0xFF8B5CF6)),
      _RuntimeMetricData(
          label: '连接时长',
          value: durationText,
          icon: Icons.schedule_rounded,
          color: keliOrange),
    ];

    return KeliCard(
      padding: EdgeInsets.all(isDesktop ? 14 : 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isDesktop) {
            return Row(
                children: items
                    .map((item) => Expanded(child: _RuntimeMetricTile(item)))
                    .toList());
          }
          if (constraints.maxWidth < 430) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => SizedBox(
                        width: width,
                        child: _CompactRuntimeMetricTile(item, dense: true),
                      ))
                  .toList(),
            );
          }
          return Row(
            children: items
                .map((item) => Expanded(child: _CompactRuntimeMetricTile(item)))
                .toList(),
          );
        },
      ),
    );
  }
}

class _RuntimeMetricData {
  const _RuntimeMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _RuntimeMetricTile extends StatelessWidget {
  const _RuntimeMetricTile(this.item);

  final _RuntimeMetricData item;

  @override
  Widget build(BuildContext context) {
    final parts = item.value.split(' ');
    final value = parts.first;
    final unit = parts.length > 1 ? parts.skip(1).join(' ') : '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSparkline = constraints.maxWidth >= 112;
        return Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: keliLineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: keliMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                                text: value,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900)),
                            if (unit.isNotEmpty)
                              TextSpan(
                                  text: ' $unit',
                                  style: const TextStyle(
                                      color: keliMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  if (showSparkline)
                    SizedBox(
                        width: 34,
                        height: 26,
                        child: CustomPaint(
                            painter: _SparklinePainter(item.color))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactRuntimeMetricTile extends StatelessWidget {
  const _CompactRuntimeMetricTile(this.item, {this.dense = false});

  final _RuntimeMetricData item;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final parts = item.value.split(' ');
    final value = parts.first;
    final unit = parts.length > 1 ? parts.skip(1).join(' ') : '';
    final label = compactMetricLabel(item.label);
    return Container(
      height: dense ? 68 : 78,
      margin: EdgeInsets.all(dense ? 0 : 3),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 17),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: keliMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                          color: keliMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final points = <Offset>[
      Offset(0, size.height * .70),
      Offset(size.width * .18, size.height * .48),
      Offset(size.width * .36, size.height * .58),
      Offset(size.width * .56, size.height * .24),
      Offset(size.width * .78, size.height * .42),
      Offset(size.width, size.height * .18),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class NodesScreen extends StatefulWidget {
  const NodesScreen({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  String query = '';
  bool autoLatencyQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (autoLatencyQueued) {
      return;
    }
    autoLatencyQueued = true;
    Future<void>.microtask(() {
      if (mounted) {
        return AppControllerScope.of(context).autoTestLatencyOnNodeListOpen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final nodes = controller.filteredNodes.where((node) {
      final lower = query.toLowerCase();
      return lower.isEmpty ||
          node.name.toLowerCase().contains(lower) ||
          node.protocol.toLowerCase().contains(lower) ||
          node.tags.any((tag) => tag.toLowerCase().contains(lower));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: '节点',
          subtitle: '选择节点、收藏和测试延迟',
          trailing: FilledButton.icon(
            onPressed:
                controller.isTestingLatency ? null : controller.testAllLatency,
            icon: const Icon(Icons.speed, size: 18),
            label: Text(controller.isTestingLatency ? '测速中' : '全部测速'),
          ),
        ),
        const SizedBox(height: 16),
        KeliCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: widget.isDesktop
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => query = value),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: '搜索节点、协议或标签',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _NodeFilterBar(
                              selected: controller.nodeFilter,
                              onChanged: controller.selectFilter),
                        ],
                      )
                    : Column(
                        children: [
                          TextField(
                            onChanged: (value) => setState(() => query = value),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '搜索节点、协议或标签',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _NodeFilterBar(
                                  selected: controller.nodeFilter,
                                  onChanged: controller.selectFilter),
                            ),
                          ),
                        ],
                      ),
              ),
              if (widget.isDesktop) const _NodeTableHeader(),
              for (final node in nodes)
                NodeRow(
                  node: node,
                  selected: controller.selectedNodeId == node.id,
                  isDesktop: widget.isDesktop,
                ),
              if (nodes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('没有匹配的节点', style: TextStyle(color: keliMuted)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class NodeRow extends StatelessWidget {
  const NodeRow({
    required this.node,
    required this.selected,
    required this.isDesktop,
    super.key,
  });

  final ProxyNode node;
  final bool selected;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final latencyColor = nodeLatencyStatusColor(controller, node);
    if (isDesktop) {
      return InkWell(
        onTap: () => controller.selectNode(node),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? keliBlueSoft : Colors.white,
            border: const Border(top: BorderSide(color: keliLineSoft)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: node.isFavorite ? '取消收藏' : '收藏',
                      onPressed: () => controller.toggleFavorite(node),
                      icon: Icon(
                        node.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: node.isFavorite ? keliOrange : keliMuted,
                        size: 20,
                      ),
                    ),
                    _NodeFlagIcon(node: node, selected: selected),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(node.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  width: 118,
                  child:
                      _MiniBadge(text: node.protocol, color: keliBlueStrong)),
              SizedBox(
                width: 110,
                child: Text(
                  nodeLatencyText(controller, node),
                  style: TextStyle(
                      color: latencyColor, fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(
                  width: 82,
                  child: Text('${node.rate.toStringAsFixed(1)}x',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(
                width: 96,
                child: Row(
                  children: [
                    StatusDot(color: node.isOnline ? keliGreen : keliRed),
                    const SizedBox(width: 7),
                    Text(node.isOnline ? '可用' : '离线',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: selected ? '当前节点' : '选择节点',
                onPressed: () => controller.selectNode(node),
                icon: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.play_circle_outline_rounded,
                    color: selected ? keliBlueStrong : keliMuted),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => controller.selectNode(node),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: isDesktop ? 18 : 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? keliBlueSoft : Colors.white,
          border: const Border(top: BorderSide(color: keliLineSoft)),
        ),
        child: Row(
          children: [
            _NodeFlagIcon(node: node, selected: selected, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(node.protocol,
                          style:
                              const TextStyle(color: keliMuted, fontSize: 12)),
                      Text('倍率 ${node.rate.toStringAsFixed(1)}x',
                          style:
                              const TextStyle(color: keliMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 72,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                nodeLatencyText(controller, node),
                style: TextStyle(
                    color: latencyColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: node.isFavorite ? '取消收藏' : '收藏',
              onPressed: () => controller.toggleFavorite(node),
              icon: Icon(
                  node.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: node.isFavorite ? keliOrange : keliMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeFilterBar extends StatelessWidget {
  const _NodeFilterBar({required this.selected, required this.onChanged});

  final NodeFilter selected;
  final ValueChanged<NodeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<NodeFilter>(
      segments: const [
        ButtonSegment(value: NodeFilter.all, label: Text('全部')),
        ButtonSegment(value: NodeFilter.lowLatency, label: Text('低延迟')),
        ButtonSegment(value: NodeFilter.favorite, label: Text('收藏')),
        ButtonSegment(value: NodeFilter.hysteria2, label: Text('HY2')),
        ButtonSegment(value: NodeFilter.vless, label: Text('VLESS')),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

class _NodeTableHeader extends StatelessWidget {
  const _NodeTableHeader();

  @override
  Widget build(BuildContext context) {
    const style =
        TextStyle(color: keliMuted, fontSize: 12, fontWeight: FontWeight.w800);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFD),
        border: Border(top: BorderSide(color: keliLineSoft)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 320, child: Text('节点名称', style: style)),
          SizedBox(width: 118, child: Text('协议', style: style)),
          SizedBox(width: 110, child: Text('延迟', style: style)),
          SizedBox(width: 82, child: Text('倍率', style: style)),
          SizedBox(width: 96, child: Text('状态', style: style)),
          Spacer(),
          SizedBox(width: 40, child: Text('操作', style: style)),
        ],
      ),
    );
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) {
      return;
    }
    loaded = true;
    Future<void>.microtask(() => AppControllerScope.of(context).refreshStore());
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= keliDesktopBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: '商店',
          subtitle: '套餐购买、流量包和订单',
          trailing: OutlinedButton.icon(
            onPressed: controller.isRefreshingStore
                ? null
                : () => controller.refreshStore(),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(controller.isRefreshingStore
                ? '刷新中'
                : isDesktop
                    ? '刷新套餐'
                    : '刷新'),
          ),
        ),
        const SizedBox(height: 16),
        _StoreCatalogPanel(controller: controller),
        const SizedBox(height: 12),
        if (controller.storeError != null) ...[
          _InlineError(message: controller.storeError!),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

enum _StoreTab { plans, traffic, orders }

class _StoreCatalogPanel extends StatefulWidget {
  const _StoreCatalogPanel({required this.controller});

  final AppController controller;

  @override
  State<_StoreCatalogPanel> createState() => _StoreCatalogPanelState();
}

class _StoreCatalogPanelState extends State<_StoreCatalogPanel> {
  _StoreTab tab = _StoreTab.plans;
  int? selectedPlanId;
  int? selectedTrafficPlanId;
  bool upgradeOnly = true;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final recurringPlans = controller.storePlans
        .where((plan) =>
            !isTrafficPackPlan(plan) && recurringOptions(plan).isNotEmpty)
        .toList();
    final upgradePlans =
        recurringPlans.where(controller.isUpgradeTarget).toList();
    final hasUpgradeTargets = upgradePlans.isNotEmpty;
    final displayedRecurringPlans =
        upgradeOnly && hasUpgradeTargets ? upgradePlans : recurringPlans;
    final trafficPlans = controller.storePlans
        .where((plan) =>
            isTrafficPackPlan(plan) && trafficOptions(plan).isNotEmpty)
        .toList();

    if (controller.isRefreshingStore && controller.storePlans.isEmpty) {
      return const KeliCard(
        child: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('正在读取可购买套餐'),
          ],
        ),
      );
    }

    if (recurringPlans.isEmpty && trafficPlans.isEmpty) {
      return const KeliCard(
        child: Text('暂无可购买套餐', style: TextStyle(color: keliMuted)),
      );
    }

    final selectedPlan =
        selectedRecurringPlan(displayedRecurringPlans, selectedPlanId);
    final selectedTrafficPlan =
        selectedStorePlan(trafficPlans, selectedTrafficPlanId);
    final selectedIsUpgrade =
        selectedPlan != null && controller.isUpgradeTarget(selectedPlan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StoreSelectionPanel(
          controller: controller,
          tab: tab,
          onTabChanged: (value) => setState(() => tab = value),
          recurringPlans: displayedRecurringPlans,
          trafficPlans: trafficPlans,
          selectedPlan: selectedPlan,
          selectedTrafficPlan: selectedTrafficPlan,
          upgradeOnly: upgradeOnly,
          hasUpgradeTargets: hasUpgradeTargets,
          onUpgradeOnlyChanged: (value) => setState(() => upgradeOnly = value),
          onSelectPlan: (id) => setState(() => selectedPlanId = id),
          onSelectTrafficPlan: (id) =>
              setState(() => selectedTrafficPlanId = id),
        ),
        const SizedBox(height: 14),
        if (tab == _StoreTab.plans)
          _StorePeriodPanel(
            title: selectedPlan == null
                ? '包月套餐 - 请选择购买周期'
                : selectedIsUpgrade
                    ? '${selectedPlan.name} - 请选择升级周期'
                    : '${selectedPlan.name} - 请选择购买周期',
            plan: selectedPlan,
            options: selectedPlan == null
                ? const []
                : recurringOptions(selectedPlan),
            controller: controller,
            isUpgrade: selectedIsUpgrade,
          )
        else if (tab == _StoreTab.traffic)
          _StorePeriodPanel(
            title: selectedTrafficPlan == null
                ? '按量付费 - 请选择购买方式'
                : '${selectedTrafficPlan.name} - 请选择购买方式',
            plan: selectedTrafficPlan,
            options: selectedTrafficPlan == null
                ? const []
                : trafficOptions(selectedTrafficPlan),
            controller: controller,
            trafficMode: true,
          )
        else
          _StoreOrdersPanel(controller: controller),
      ],
    );
  }
}

class _StoreSelectionPanel extends StatelessWidget {
  const _StoreSelectionPanel({
    required this.controller,
    required this.tab,
    required this.onTabChanged,
    required this.recurringPlans,
    required this.trafficPlans,
    required this.selectedPlan,
    required this.selectedTrafficPlan,
    required this.upgradeOnly,
    required this.hasUpgradeTargets,
    required this.onUpgradeOnlyChanged,
    required this.onSelectPlan,
    required this.onSelectTrafficPlan,
  });

  final AppController controller;
  final _StoreTab tab;
  final ValueChanged<_StoreTab> onTabChanged;
  final List<StorePlan> recurringPlans;
  final List<StorePlan> trafficPlans;
  final StorePlan? selectedPlan;
  final StorePlan? selectedTrafficPlan;
  final bool upgradeOnly;
  final bool hasUpgradeTargets;
  final ValueChanged<bool> onUpgradeOnlyChanged;
  final ValueChanged<int> onSelectPlan;
  final ValueChanged<int> onSelectTrafficPlan;

  @override
  Widget build(BuildContext context) {
    return KeliCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreTabs(current: tab, onChanged: onTabChanged),
          const CardDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: switch (tab) {
              _StoreTab.plans => _MonthlyPlanSelection(
                  controller: controller,
                  plans: recurringPlans,
                  selectedPlan: selectedPlan,
                  upgradeOnly: upgradeOnly,
                  hasUpgradeTargets: hasUpgradeTargets,
                  onUpgradeOnlyChanged: onUpgradeOnlyChanged,
                  onSelectPlan: onSelectPlan,
                ),
              _StoreTab.traffic => _TrafficPlanSelection(
                  plans: trafficPlans,
                  selectedPlan: selectedTrafficPlan,
                  onSelectPlan: onSelectTrafficPlan,
                ),
              _StoreTab.orders => const _OrderTabSelection(),
            },
          ),
        ],
      ),
    );
  }
}

class _StoreTabs extends StatelessWidget {
  const _StoreTabs({required this.current, required this.onChanged});

  final _StoreTab current;
  final ValueChanged<_StoreTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: keliLineSoft),
          ),
          child: Row(
            children: [
              _StoreTabButton(
                icon: Icons.workspace_premium_outlined,
                label: '包月套餐',
                selected: current == _StoreTab.plans,
                onTap: () => onChanged(_StoreTab.plans),
              ),
              _StoreTabButton(
                icon: Icons.attach_money_rounded,
                label: '按量付费',
                selected: current == _StoreTab.traffic,
                onTap: () => onChanged(_StoreTab.traffic),
              ),
              _StoreTabButton(
                icon: Icons.schedule_rounded,
                label: '订单',
                selected: current == _StoreTab.orders,
                onTap: () => onChanged(_StoreTab.orders),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreTabButton extends StatelessWidget {
  const _StoreTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.055),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: selected ? keliBlueStrong : keliMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? keliInk : keliMuted,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyPlanSelection extends StatelessWidget {
  const _MonthlyPlanSelection({
    required this.controller,
    required this.plans,
    required this.selectedPlan,
    required this.upgradeOnly,
    required this.hasUpgradeTargets,
    required this.onUpgradeOnlyChanged,
    required this.onSelectPlan,
  });

  final AppController controller;
  final List<StorePlan> plans;
  final StorePlan? selectedPlan;
  final bool upgradeOnly;
  final bool hasUpgradeTargets;
  final ValueChanged<bool> onUpgradeOnlyChanged;
  final ValueChanged<int> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UpgradeRuleBanner(
          upgradeOnly: upgradeOnly,
          hasUpgradeTargets: hasUpgradeTargets,
          currentPlanName: controller.profile?.planName ?? '',
          onUpgradeOnlyChanged: onUpgradeOnlyChanged,
        ),
        const SizedBox(height: 22),
        const Text('套餐选择',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        if (plans.isEmpty)
          const _EmptyStoreBox(message: '暂无可购买包月套餐')
        else
          _PlanChoiceWrap(
            plans: plans,
            selectedPlan: selectedPlan,
            onSelectPlan: onSelectPlan,
            showUpgradeBadge: controller.isUpgradeTarget,
          ),
      ],
    );
  }
}

class _TrafficPlanSelection extends StatelessWidget {
  const _TrafficPlanSelection({
    required this.plans,
    required this.selectedPlan,
    required this.onSelectPlan,
  });

  final List<StorePlan> plans;
  final StorePlan? selectedPlan;
  final ValueChanged<int> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StoreHintStrip(
          icon: Icons.info_outline,
          title: '购买说明',
          text: '按量付费不会替换当前包月套餐，支付后按面板订单规则立即生效。',
        ),
        const SizedBox(height: 18),
        const Text('套餐选择',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        if (plans.isEmpty)
          const _EmptyStoreBox(message: '暂无可购买按量付费套餐')
        else
          _PlanChoiceWrap(
            plans: plans,
            selectedPlan: selectedPlan,
            onSelectPlan: onSelectPlan,
            showUpgradeBadge: (_) => false,
          ),
      ],
    );
  }
}

class _StoreHintStrip extends StatelessWidget {
  const _StoreHintStrip({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: keliBlueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: keliBlueStrong),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: keliMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeRuleBanner extends StatelessWidget {
  const _UpgradeRuleBanner({
    required this.upgradeOnly,
    required this.hasUpgradeTargets,
    required this.currentPlanName,
    required this.onUpgradeOnlyChanged,
  });

  final bool upgradeOnly;
  final bool hasUpgradeTargets;
  final String currentPlanName;
  final ValueChanged<bool> onUpgradeOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final title = hasUpgradeTargets ? '升级套餐' : '当前暂无可升级目标';
          final subtitle = hasUpgradeTargets
              ? '当前套餐：${currentPlanName.isEmpty ? '未识别' : currentPlanName}，确认后立即覆盖生效。'
              : '可购买普通套餐；若需要升级，请确认面板套餐白名单和升级开关。';
          final text = Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: keliBlueSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.upgrade_rounded,
                    size: 18, color: keliBlueStrong),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: keliMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DarkTinyButton(
                label: '只看可升级',
                active: upgradeOnly,
                onTap:
                    hasUpgradeTargets ? () => onUpgradeOnlyChanged(true) : null,
              ),
              _LightTinyButton(
                label: '查看全部',
                active: !upgradeOnly,
                onTap: () => onUpgradeOnlyChanged(false),
              ),
              const _RuleTinyButton(),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _DarkTinyButton extends StatelessWidget {
  const _DarkTinyButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: active ? keliBlueStrong : const Color(0xFFEFF3F8),
        foregroundColor: active ? Colors.white : keliInk,
        minimumSize: const Size(84, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(label),
    );
  }
}

class _LightTinyButton extends StatelessWidget {
  const _LightTinyButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? const Color(0xFFF3F6FA) : Colors.white,
        minimumSize: const Size(84, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(label),
    );
  }
}

class _RuleTinyButton extends StatelessWidget {
  const _RuleTinyButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('升级和重置规则以面板订单规则为准')),
        );
      },
      icon: const Icon(Icons.info_outline, size: 16),
      label: const Text('查看规则'),
      style: TextButton.styleFrom(
        foregroundColor: keliMuted,
        minimumSize: const Size(88, 36),
      ),
    );
  }
}

class _PlanChoiceWrap extends StatelessWidget {
  const _PlanChoiceWrap({
    required this.plans,
    required this.selectedPlan,
    required this.onSelectPlan,
    required this.showUpgradeBadge,
  });

  final List<StorePlan> plans;
  final StorePlan? selectedPlan;
  final ValueChanged<int> onSelectPlan;
  final bool Function(StorePlan plan) showUpgradeBadge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth < 520;
        final buttons = [
          for (final plan in plans)
            _PlanChoiceButton(
              plan: plan,
              selected: selectedPlan?.id == plan.id,
              showUpgradeBadge: showUpgradeBadge(plan),
              fullWidth: fullWidth,
              onTap: () => onSelectPlan(plan.id),
            ),
        ];
        if (fullWidth) {
          return Column(
            children: [
              for (var index = 0; index < buttons.length; index++) ...[
                SizedBox(width: double.infinity, child: buttons[index]),
                if (index != buttons.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Wrap(spacing: 8, runSpacing: 10, children: buttons);
      },
    );
  }
}

class _PlanChoiceButton extends StatelessWidget {
  const _PlanChoiceButton({
    required this.plan,
    required this.selected,
    required this.showUpgradeBadge,
    required this.fullWidth,
    required this.onTap,
  });

  final StorePlan plan;
  final bool selected;
  final bool showUpgradeBadge;
  final bool fullWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '${plan.name} | ${plan.trafficLabel}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: selected ? keliInk : keliMuted,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
    return Material(
      color: selected ? keliBlueSoft : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFFD8E8FF) : keliLine,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (fullWidth) Expanded(child: label) else label,
              if (showUpgradeBadge) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('可升级',
                      style: TextStyle(
                          color: keliMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTabSelection extends StatelessWidget {
  const _OrderTabSelection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StoreHintStrip(
          icon: Icons.receipt_long_outlined,
          title: '订单管理',
          text: '客户端内购买会直接创建面板订单，支付完成后会自动刷新套餐和节点数据。',
        ),
      ],
    );
  }
}

class _StorePeriodPanel extends StatelessWidget {
  const _StorePeriodPanel({
    required this.title,
    required this.plan,
    required this.options,
    required this.controller,
    this.trafficMode = false,
    this.isUpgrade = false,
  });

  final String title;
  final StorePlan? plan;
  final List<PlanPeriodOption> options;
  final AppController controller;
  final bool trafficMode;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: KeliCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            if (plan != null && plan!.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan!.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: keliMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (plan == null || options.isEmpty)
              const _EmptyStoreBox(message: '当前没有可购买项目')
            else
              _StorePriceGrid(
                plan: plan!,
                options: options,
                controller: controller,
                trafficMode: trafficMode,
                isUpgrade: isUpgrade,
              ),
          ],
        ),
      ),
    );
  }
}

class _StorePriceGrid extends StatelessWidget {
  const _StorePriceGrid({
    required this.plan,
    required this.options,
    required this.controller,
    required this.trafficMode,
    required this.isUpgrade,
  });

  final StorePlan plan;
  final List<PlanPeriodOption> options;
  final AppController controller;
  final bool trafficMode;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final option in options)
              SizedBox(
                width: width,
                child: _StorePricingCard(
                  plan: plan,
                  option: option,
                  controller: controller,
                  trafficMode: trafficMode,
                  isUpgrade: isUpgrade,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StorePricingCard extends StatelessWidget {
  const _StorePricingCard({
    required this.plan,
    required this.option,
    required this.controller,
    required this.trafficMode,
    required this.isUpgrade,
  });

  final StorePlan plan;
  final PlanPeriodOption option;
  final AppController controller;
  final bool trafficMode;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.026),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: keliBlueSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD8E8FF)),
                ),
                child: Text(option.label,
                    style: const TextStyle(
                        color: keliBlueStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('￥',
                    style: TextStyle(
                        color: keliMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    trafficMode
                        ? priceNumberText(option.priceCents)
                        : monthlyPriceNumberText(option),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(trafficMode ? '总价' : '每月',
                    style: const TextStyle(
                        color: keliMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: keliLineSoft),
          const SizedBox(height: 12),
          _PlanSpecRow(
              icon: Icons.devices_outlined,
              label: '设备',
              value: plan.deviceLimit == null || plan.deviceLimit == 0
                  ? '无限制'
                  : '${plan.deviceLimit} 台'),
          _PlanSpecRow(
              icon: Icons.wifi_rounded,
              label: trafficMode ? '流量' : '月流量',
              value: plan.trafficLabel),
          _PlanSpecRow(
              icon: Icons.rocket_launch_outlined,
              label: '速率',
              value: plan.speedLimit == null || plan.speedLimit == 0
                  ? '无限制'
                  : '${plan.speedLimit!.toStringAsFixed(0)} Mbps'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton.icon(
              onPressed: controller.isPurchasing
                  ? null
                  : () => handleStoreBuy(
                        context,
                        controller,
                        plan,
                        option,
                        isUpgrade: isUpgrade,
                      ),
              icon: Icon(
                isUpgrade ? Icons.upgrade_rounded : Icons.shopping_bag_outlined,
                size: 17,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: keliBlueStrong,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              label: Text(controller.isPurchasing
                  ? '处理中'
                  : isUpgrade
                      ? '升级购买'
                      : '立即购买'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSpecRow extends StatelessWidget {
  const _PlanSpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: keliBlueStrong),
          const SizedBox(width: 8),
          Text('$label：',
              style: const TextStyle(
                  color: keliMuted, fontSize: 12, fontWeight: FontWeight.w800)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: keliInk,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCheckoutDialog(
  BuildContext context,
  AppController controller,
  StorePlan plan,
  PlanPeriodOption option, {
  bool isUpgrade = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !controller.isPurchasing,
    builder: (_) => _CheckoutDialog(
      controller: controller,
      plan: plan,
      option: option,
      isUpgrade: isUpgrade,
    ),
  );
}

enum _PendingOrderAction { payExisting, cancelAndContinue }

Future<void> handleStoreBuy(
  BuildContext context,
  AppController controller,
  StorePlan plan,
  PlanPeriodOption option, {
  bool isUpgrade = false,
}) async {
  final pending = controller.pendingOrder;
  if (pending == null) {
    return showCheckoutDialog(
      context,
      controller,
      plan,
      option,
      isUpgrade: isUpgrade,
    );
  }

  final action = await showPendingOrderGuardDialog(context, pending);
  if (!context.mounted || action == null) {
    return;
  }
  switch (action) {
    case _PendingOrderAction.payExisting:
      await showExistingOrderPaymentDialog(
        context: context,
        controller: controller,
        order: pending,
      );
      break;
    case _PendingOrderAction.cancelAndContinue:
      try {
        await controller.cancelStoreOrder(pending.tradeNo);
        if (!context.mounted) {
          return;
        }
        await showCheckoutDialog(
          context,
          controller,
          plan,
          option,
          isUpgrade: isUpgrade,
        );
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('取消订单失败: $error')));
        }
      }
      break;
  }
}

Future<_PendingOrderAction?> showPendingOrderGuardDialog(
  BuildContext context,
  StoreOrder order,
) {
  return showDialog<_PendingOrderAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('已有待支付订单'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('面板同一时间只允许存在一个未完成订单。请先支付或取消当前订单。'),
          const SizedBox(height: 14),
          _PendingOrderSummary(order: order),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, _PendingOrderAction.cancelAndContinue),
          child: const Text('取消并继续'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _PendingOrderAction.payExisting),
          child: const Text('去支付已有订单'),
        ),
      ],
    ),
  );
}

Future<void> confirmCancelStoreOrder(
  BuildContext context,
  AppController controller,
  StoreOrder order,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('取消订单'),
      content: Text('确定取消订单 ${order.tradeNo} 吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: keliRed),
          child: const Text('确认取消'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await controller.cancelStoreOrder(order.tradeNo);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('订单已取消')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('取消订单失败: $error')));
    }
  }
}

Future<void> showStoreOrderDetailDialog(
  BuildContext context,
  StoreOrder order,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('订单详情'),
      content: _StoreOrderDetail(order: order),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

Future<void> showExistingOrderPaymentDialog({
  required BuildContext context,
  required AppController controller,
  required StoreOrder order,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !controller.isPurchasing,
    builder: (_) => _ExistingOrderPaymentDialog(
      controller: controller,
      order: order,
    ),
  );
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.controller,
    required this.plan,
    required this.option,
    required this.isUpgrade,
  });

  final AppController controller;
  final StorePlan plan;
  final PlanPeriodOption option;
  final bool isUpgrade;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String? methodId;
  String? tradeNo;
  bool creatingOrder = false;
  bool paying = false;
  bool cancelling = false;
  bool checking = false;
  bool refreshing = false;
  PurchaseResult? result;
  String? resultDetail;
  bool resultIsError = false;
  UpgradePreview? upgradePreview;
  bool previewLoading = false;
  String? previewError;

  @override
  void initState() {
    super.initState();
    final methods = widget.controller.paymentMethods;
    final current = widget.controller.selectedPaymentMethodId;
    methodId = methods.any((method) => method.id == current)
        ? current
        : defaultPaymentMethodId(methods);
    if (widget.isUpgrade) {
      unawaited(loadUpgradePreview());
    }
  }

  Future<UpgradePreview?> loadUpgradePreview() async {
    if (previewLoading) {
      return upgradePreview;
    }
    setState(() {
      previewLoading = true;
      previewError = null;
    });
    try {
      final preview = await widget.controller.previewUpgrade(
        widget.plan,
        widget.option,
      );
      if (!mounted) {
        return preview;
      }
      setState(() {
        upgradePreview = preview;
        previewError =
            preview.allowUpgrade ? null : preview.reason ?? '当前套餐暂不可升级';
      });
      return preview;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      setState(() {
        upgradePreview = null;
        previewError = '$error';
      });
      return null;
    } finally {
      if (mounted) {
        setState(() => previewLoading = false);
      }
    }
  }

  Future<UpgradePreview?> ensureUpgradePreview() async {
    if (!widget.isUpgrade) {
      return null;
    }
    final preview = upgradePreview ?? await loadUpgradePreview();
    if (preview == null || !preview.allowUpgrade) {
      setState(() {
        result = PurchaseResult(
            message: '创建失败: ${previewError ?? preview?.reason ?? '升级预览失败'}');
        resultDetail = null;
        resultIsError = true;
      });
      return null;
    }
    if (preview.quoteToken == null || preview.quoteToken!.trim().isEmpty) {
      setState(() {
        result = const PurchaseResult(message: '创建失败: 升级预览缺少 quote_token');
        resultDetail = null;
        resultIsError = true;
      });
      return null;
    }
    return preview;
  }

  Future<void> createOrder() async {
    if (creatingOrder || tradeNo != null) {
      return;
    }
    setState(() {
      creatingOrder = true;
      result = null;
      resultDetail = null;
      resultIsError = false;
    });

    try {
      final preview = await ensureUpgradePreview();
      if (widget.isUpgrade && preview == null) {
        return;
      }

      final createdTradeNo = widget.isUpgrade
          ? await widget.controller
              .createUpgradeOrder(quoteToken: preview!.quoteToken!)
          : await widget.controller.createPlanOrder(widget.plan, widget.option);
      if (!mounted) {
        return;
      }
      setState(() {
        tradeNo = createdTradeNo;
        result = PurchaseResult(
          message: widget.isUpgrade ? '升级订单已创建' : '订单已创建',
          tradeNo: createdTradeNo,
          copyText: createdTradeNo,
        );
        resultDetail = '订单号已生成，可以继续支付；支付失败时可重试或取消订单。';
        resultIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        result = PurchaseResult(message: '创建失败: $error');
        resultDetail = null;
        resultIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => creatingOrder = false);
      }
    }
  }

  Future<void> payOrder() async {
    final currentTradeNo = tradeNo;
    if (paying || currentTradeNo == null) {
      return;
    }
    setState(() {
      paying = true;
      result = null;
      resultDetail = null;
      resultIsError = false;
    });

    if (methodId != null) {
      widget.controller.selectPaymentMethod(methodId);
    }

    final purchase = await widget.controller.payOrder(
      tradeNo: currentTradeNo,
      paymentMethodId: methodId,
      allowNoPaymentMethod: !widget.isUpgrade && widget.option.priceCents <= 0,
      successMessage: widget.isUpgrade ? '升级成功，套餐已刷新' : '支付成功，套餐已刷新',
      externalMessage: widget.isUpgrade ? '升级订单已创建，正在打开支付页面' : '正在打开支付页面',
    );

    await handlePaymentResult(purchase);

    if (mounted) {
      setState(() => paying = false);
    }
  }

  Future<void> handlePaymentResult(PurchaseResult purchase) async {
    var detail = '';
    if (purchase.copyText != null) {
      await Clipboard.setData(ClipboardData(text: purchase.copyText!));
      detail = '支付信息或订单号已复制到剪贴板';
    }
    if (purchase.externalUrl != null && mounted) {
      final opened = await openExternalUrl(purchase.externalUrl!);
      if (opened) {
        detail = '支付页面已打开，完成后可回到客户端刷新套餐';
      } else {
        await Clipboard.setData(ClipboardData(text: purchase.externalUrl!));
        detail = '支付链接打开失败，已复制到剪贴板';
      }
    }
    if (purchase.qrPayload != null) {
      detail = '请在弹出的二维码窗口完成支付，付款后可查询状态并刷新套餐';
    }

    if (!mounted) {
      return;
    }
    setState(() {
      result = purchase;
      resultDetail = detail.isEmpty ? null : detail;
      resultIsError = purchase.message.startsWith('购买失败') ||
          purchase.message.startsWith('支付失败');
    });
    if (purchase.qrPayload != null) {
      unawaited(showCheckoutQrDialog(
        context: context,
        controller: widget.controller,
        payload: purchase.qrPayload!,
        tradeNo: purchase.tradeNo ?? tradeNo,
        successMessage: widget.isUpgrade ? '升级成功，套餐已刷新' : '支付成功，套餐已刷新',
      ));
    }
  }

  Future<void> checkPaymentStatus() async {
    final currentTradeNo = tradeNo;
    if (currentTradeNo == null || checking) {
      return;
    }
    setState(() => checking = true);
    try {
      final status = await widget.controller.checkStoreOrder(currentTradeNo);
      if (!mounted) {
        return;
      }
      if (status == 3) {
        await widget.controller.bootstrap();
        await widget.controller.refreshOrders();
        if (!mounted) {
          return;
        }
        setState(() {
          result = PurchaseResult(
              message: widget.isUpgrade ? '升级成功，套餐已刷新' : '支付成功，套餐已刷新',
              tradeNo: currentTradeNo);
          resultDetail = null;
          resultIsError = false;
        });
      } else {
        setState(() {
          result = PurchaseResult(message: '订单尚未完成支付', tradeNo: currentTradeNo);
          resultDetail = '当前状态码：$status';
          resultIsError = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        result =
            PurchaseResult(message: '查询失败: $error', tradeNo: currentTradeNo);
        resultDetail = null;
        resultIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => checking = false);
      }
    }
  }

  Future<void> cancelOrder() async {
    final currentTradeNo = tradeNo;
    if (currentTradeNo == null || cancelling) {
      return;
    }
    setState(() => cancelling = true);
    try {
      await widget.controller.cancelStoreOrder(currentTradeNo);
      if (!mounted) {
        return;
      }
      setState(() {
        tradeNo = null;
        result = const PurchaseResult(message: '订单已取消');
        resultDetail = widget.isUpgrade ? '升级订单已取消，如需继续升级请重新预览并创建订单。' : null;
        resultIsError = false;
        if (widget.isUpgrade) {
          upgradePreview = null;
          previewError = null;
        }
      });
      if (widget.isUpgrade) {
        unawaited(loadUpgradePreview());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        result =
            PurchaseResult(message: '取消失败: $error', tradeNo: currentTradeNo);
        resultDetail = null;
        resultIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => cancelling = false);
      }
    }
  }

  Future<void> refreshAccount() async {
    setState(() => refreshing = true);
    await widget.controller.bootstrap();
    if (!mounted) {
      return;
    }
    setState(() => refreshing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('套餐和节点已刷新')));
  }

  @override
  Widget build(BuildContext context) {
    final methods = widget.controller.paymentMethods;
    final payableCents = widget.isUpgrade
        ? upgradePreview?.payableAmountCents ?? widget.option.priceCents
        : widget.option.priceCents;
    final hasTradeNo = tradeNo != null;
    final canFreePay = !widget.isUpgrade && widget.option.priceCents <= 0;
    final canPay = hasTradeNo &&
        (methodId != null || canFreePay || methods.isEmpty) &&
        !creatingOrder &&
        !paying &&
        !cancelling;
    final upgradeBlocked = widget.isUpgrade &&
        previewError != null &&
        upgradePreview?.allowUpgrade != true;
    final canCreate = !hasTradeNo &&
        !creatingOrder &&
        !paying &&
        !previewLoading &&
        !upgradeBlocked;
    final busy =
        creatingOrder || paying || cancelling || checking || refreshing;
    final createText = widget.isUpgrade ? '创建升级订单' : '创建订单';
    final payText = methods.isEmpty && payableCents > 0 ? '复制订单号' : '立即支付';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: keliBlueSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              widget.isUpgrade
                                  ? Icons.upgrade_rounded
                                  : Icons.shopping_bag_outlined,
                              color: keliBlueStrong,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.isUpgrade ? '确认升级' : '确认订单',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(
                                  widget.isUpgrade
                                      ? '先预览补差价，再创建升级订单并支付'
                                      : '核对套餐、选择支付方式后创建订单',
                                  style: TextStyle(
                                      color: keliMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _CheckoutSteps(),
                    const SizedBox(height: 16),
                    _CheckoutSummary(
                      plan: widget.plan,
                      option: widget.option,
                    ),
                    if (widget.isUpgrade) ...[
                      const SizedBox(height: 12),
                      _UpgradePreviewBox(
                        preview: upgradePreview,
                        loading: previewLoading,
                        error: previewError,
                      ),
                    ],
                    if (hasTradeNo) ...[
                      const SizedBox(height: 12),
                      _CheckoutOrderBox(tradeNo: tradeNo!),
                    ],
                    const SizedBox(height: 16),
                    if (hasTradeNo) ...[
                      const Text('支付方式',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (methods.isEmpty)
                        const _CheckoutInfoBox(
                          icon: Icons.info_outline,
                          title: '暂无可选支付方式',
                          message: '订单已创建，可复制订单号到面板处理。',
                        )
                      else
                        Column(
                          children: [
                            for (final method in methods) ...[
                              _PaymentMethodTile(
                                method: method,
                                selected: method.id == methodId,
                                onTap: busy
                                    ? null
                                    : () =>
                                        setState(() => methodId = method.id),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                    ],
                    const SizedBox(height: 14),
                    if (result != null) ...[
                      _CheckoutResultBox(
                        result: result!,
                        detail: resultDetail,
                        isError: resultIsError,
                      ),
                      const SizedBox(height: 14),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final closeButton = OutlinedButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('关闭'),
                        );
                        final refreshButton = result != null && !resultIsError
                            ? OutlinedButton.icon(
                                onPressed: refreshing ? null : refreshAccount,
                                icon: refreshing
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh, size: 17),
                                label: Text(refreshing ? '刷新中' : '刷新套餐'),
                              )
                            : null;
                        final createButton = FilledButton.icon(
                          onPressed: canCreate ? createOrder : null,
                          icon: creatingOrder
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.receipt_long_outlined,
                                  size: 17),
                          label: Text(previewLoading
                              ? '正在预览'
                              : creatingOrder
                                  ? '处理中'
                                  : createText),
                        );
                        final payButton = FilledButton.icon(
                          onPressed: canPay
                              ? methods.isEmpty && !canFreePay
                                  ? () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: tradeNo!));
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {
                                        result = PurchaseResult(
                                            message: '订单号已复制',
                                            tradeNo: tradeNo);
                                        resultDetail = '可以到面板订单页继续支付。';
                                        resultIsError = false;
                                      });
                                    }
                                  : payOrder
                              : null,
                          icon: paying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.payment_outlined, size: 17),
                          label: Text(paying ? '支付中' : payText),
                        );
                        final cancelButton = OutlinedButton.icon(
                          onPressed: hasTradeNo && !busy ? cancelOrder : null,
                          icon: cancelling
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.close_rounded, size: 17),
                          label: Text(cancelling ? '取消中' : '取消订单'),
                        );
                        final checkButton = OutlinedButton.icon(
                          onPressed:
                              hasTradeNo && !busy ? checkPaymentStatus : null,
                          icon: checking
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.fact_check_outlined, size: 17),
                          label: Text(checking ? '查询中' : '查询状态'),
                        );

                        if (constraints.maxWidth < 430) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasTradeNo) ...[
                                payButton,
                                const SizedBox(height: 8),
                                checkButton,
                                const SizedBox(height: 8),
                                cancelButton,
                              ] else
                                createButton,
                              if (refreshButton != null) ...[
                                const SizedBox(height: 8),
                                refreshButton,
                              ],
                              const SizedBox(height: 8),
                              closeButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: closeButton),
                            if (hasTradeNo) ...[
                              const SizedBox(width: 10),
                              Expanded(child: cancelButton),
                              const SizedBox(width: 10),
                              Expanded(child: checkButton),
                            ] else if (refreshButton != null) ...[
                              const SizedBox(width: 10),
                              Expanded(child: refreshButton),
                            ],
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: hasTradeNo ? payButton : createButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExistingOrderPaymentDialog extends StatefulWidget {
  const _ExistingOrderPaymentDialog({
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final StoreOrder order;

  @override
  State<_ExistingOrderPaymentDialog> createState() =>
      _ExistingOrderPaymentDialogState();
}

class _ExistingOrderPaymentDialogState
    extends State<_ExistingOrderPaymentDialog> {
  String? methodId;
  bool paying = false;
  bool checking = false;
  bool cancelling = false;
  bool orderClosed = false;
  PurchaseResult? result;
  String? resultDetail;
  bool resultIsError = false;

  @override
  void initState() {
    super.initState();
    methodId = widget.controller.selectedPaymentMethodId ??
        defaultPaymentMethodId(widget.controller.paymentMethods);
  }

  Future<void> payOrder() async {
    if (paying || orderClosed || !widget.order.isPending) {
      return;
    }
    final methods = widget.controller.paymentMethods;
    final canFreePay = widget.order.totalAmountCents <= 0;
    if (methodId == null && !canFreePay) {
      setState(() {
        result = PurchaseResult(
          message: '请选择支付方式，或复制订单号到面板支付',
          tradeNo: widget.order.tradeNo,
          copyText: widget.order.tradeNo,
        );
        resultDetail = null;
        resultIsError = false;
      });
      return;
    }
    if (methods.isEmpty && !canFreePay) {
      await Clipboard.setData(ClipboardData(text: widget.order.tradeNo));
      if (!mounted) {
        return;
      }
      setState(() {
        result =
            PurchaseResult(message: '订单号已复制', tradeNo: widget.order.tradeNo);
        resultDetail = '可以到面板订单页继续支付。';
        resultIsError = false;
      });
      return;
    }

    setState(() {
      paying = true;
      result = null;
      resultDetail = null;
      resultIsError = false;
    });
    if (methodId != null) {
      widget.controller.selectPaymentMethod(methodId);
    }
    final purchase = await widget.controller.payOrder(
      tradeNo: widget.order.tradeNo,
      paymentMethodId: methodId,
      allowNoPaymentMethod: canFreePay,
      successMessage: '支付成功，套餐已刷新',
      externalMessage: '正在打开支付页面',
    );
    await handlePaymentResult(purchase);
    if (mounted) {
      setState(() => paying = false);
    }
  }

  Future<void> handlePaymentResult(PurchaseResult purchase) async {
    var detail = '';
    if (purchase.copyText != null) {
      await Clipboard.setData(ClipboardData(text: purchase.copyText!));
      detail = '支付信息或订单号已复制到剪贴板';
    }
    if (purchase.externalUrl != null && mounted) {
      final opened = await openExternalUrl(purchase.externalUrl!);
      if (opened) {
        detail = '支付页面已打开，完成后可回到客户端刷新套餐';
      } else {
        await Clipboard.setData(ClipboardData(text: purchase.externalUrl!));
        detail = '支付链接打开失败，已复制到剪贴板';
      }
    }
    if (purchase.qrPayload != null) {
      detail = '请在弹出的二维码窗口完成支付，付款后可查询状态并刷新套餐';
    }
    if (!mounted) {
      return;
    }
    setState(() {
      result = purchase;
      resultDetail = detail.isEmpty ? null : detail;
      resultIsError = purchase.message.startsWith('购买失败') ||
          purchase.message.startsWith('支付失败');
    });
    if (purchase.qrPayload != null) {
      unawaited(showCheckoutQrDialog(
        context: context,
        controller: widget.controller,
        payload: purchase.qrPayload!,
        tradeNo: purchase.tradeNo ?? widget.order.tradeNo,
        successMessage: '支付成功，套餐已刷新',
      ));
    }
  }

  Future<void> checkPaymentStatus() async {
    if (checking) {
      return;
    }
    setState(() => checking = true);
    try {
      final status =
          await widget.controller.checkStoreOrder(widget.order.tradeNo);
      if (!mounted) {
        return;
      }
      if (status == 3) {
        await widget.controller.bootstrap();
        await widget.controller.refreshOrders();
        if (!mounted) {
          return;
        }
        setState(() {
          result = PurchaseResult(
              message: '支付成功，套餐已刷新', tradeNo: widget.order.tradeNo);
          resultDetail = null;
          resultIsError = false;
          orderClosed = true;
        });
      } else {
        setState(() {
          result = PurchaseResult(
              message: '订单尚未完成支付', tradeNo: widget.order.tradeNo);
          resultDetail = '当前状态码：$status';
          resultIsError = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        result = PurchaseResult(
            message: '查询失败: $error', tradeNo: widget.order.tradeNo);
        resultDetail = null;
        resultIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => checking = false);
      }
    }
  }

  Future<void> cancelOrder() async {
    if (cancelling) {
      return;
    }
    setState(() => cancelling = true);
    try {
      await widget.controller.cancelStoreOrder(widget.order.tradeNo);
      if (!mounted) {
        return;
      }
      setState(() {
        result = const PurchaseResult(message: '订单已取消');
        resultDetail = null;
        resultIsError = false;
        orderClosed = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        result = PurchaseResult(
            message: '取消失败: $error', tradeNo: widget.order.tradeNo);
        resultDetail = null;
        resultIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = widget.controller.paymentMethods;
    final canFreePay = widget.order.totalAmountCents <= 0;
    final activePending = widget.order.isPending && !orderClosed;
    final busy = paying || checking || cancelling;
    final canPay = activePending &&
        !busy &&
        (methodId != null || canFreePay || methods.isEmpty);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: keliBlueSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_outlined,
                              color: keliBlueStrong, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('处理已有订单',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 2),
                              Text('继续支付或取消这个待支付订单',
                                  style: TextStyle(
                                      color: keliMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PendingOrderSummary(order: widget.order),
                    const SizedBox(height: 16),
                    if (activePending) ...[
                      const Text('支付方式',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (methods.isEmpty && !canFreePay)
                        const _CheckoutInfoBox(
                          icon: Icons.info_outline,
                          title: '暂无可选支付方式',
                          message: '可以复制订单号到面板继续处理。',
                        )
                      else
                        Column(
                          children: [
                            for (final method in methods) ...[
                              _PaymentMethodTile(
                                method: method,
                                selected: method.id == methodId,
                                onTap: busy
                                    ? null
                                    : () =>
                                        setState(() => methodId = method.id),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      const SizedBox(height: 14),
                    ],
                    if (result != null) ...[
                      _CheckoutResultBox(
                        result: result!,
                        detail: resultDetail,
                        isError: resultIsError,
                      ),
                      const SizedBox(height: 14),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final closeButton = OutlinedButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('关闭'),
                        );
                        final cancelButton = OutlinedButton.icon(
                          onPressed:
                              activePending && !busy ? cancelOrder : null,
                          icon: cancelling
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.close_rounded, size: 17),
                          label: Text(cancelling ? '取消中' : '取消订单'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: keliRed),
                        );
                        final checkButton = OutlinedButton.icon(
                          onPressed: activePending && !busy
                              ? checkPaymentStatus
                              : null,
                          icon: checking
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.fact_check_outlined, size: 17),
                          label: Text(checking ? '查询中' : '查询状态'),
                        );
                        final payButton = FilledButton.icon(
                          onPressed: canPay ? payOrder : null,
                          icon: paying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.payment_outlined, size: 17),
                          label: Text(paying ? '支付中' : '立即支付'),
                        );

                        if (constraints.maxWidth < 430) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              payButton,
                              const SizedBox(height: 8),
                              checkButton,
                              const SizedBox(height: 8),
                              cancelButton,
                              const SizedBox(height: 8),
                              closeButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: closeButton),
                            const SizedBox(width: 10),
                            Expanded(child: cancelButton),
                            const SizedBox(width: 10),
                            Expanded(child: checkButton),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: payButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingOrderSummary extends StatelessWidget {
  const _PendingOrderSummary({required this.order});

  final StoreOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Column(
        children: [
          _StoreOrderDetailLine(label: '订单号', value: order.tradeNo),
          _StoreOrderDetailLine(label: '套餐', value: storeOrderPlanName(order)),
          _StoreOrderDetailLine(
              label: '周期', value: orderPeriodText(order.period)),
          _StoreOrderDetailLine(
              label: '状态', value: orderStatusText(order.status)),
          _StoreOrderDetailLine(
              label: '金额', value: priceText(order.totalAmountCents)),
          _StoreOrderDetailLine(
              label: '创建时间', value: storeOrderDateText(order.createdAt)),
        ],
      ),
    );
  }
}

class _StoreOrderDetail extends StatelessWidget {
  const _StoreOrderDetail({required this.order});

  final StoreOrder order;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StoreOrderDetailLine(label: '订单号', value: order.tradeNo),
          _StoreOrderDetailLine(label: '套餐', value: storeOrderPlanName(order)),
          if (order.isDiscountUpgrade) ...[
            _StoreOrderDetailLine(
                label: '原套餐', value: order.upgradeSourcePlanName ?? '-'),
            _StoreOrderDetailLine(
                label: '目标套餐', value: order.upgradeTargetPlanName ?? '-'),
          ],
          _StoreOrderDetailLine(
              label: '周期', value: orderPeriodText(order.period)),
          _StoreOrderDetailLine(
              label: '状态', value: orderStatusText(order.status)),
          _StoreOrderDetailLine(
              label: '订单金额', value: priceText(order.totalAmountCents)),
          if (order.discountAmountCents != null)
            _StoreOrderDetailLine(
                label: '优惠金额', value: priceText(order.discountAmountCents!)),
          if (order.balanceAmountCents != null)
            _StoreOrderDetailLine(
                label: '余额抵扣', value: priceText(order.balanceAmountCents!)),
          if (order.handlingAmountCents != null)
            _StoreOrderDetailLine(
                label: '手续费', value: priceText(order.handlingAmountCents!)),
          if (order.upgradeCreditAmountCents != null)
            _StoreOrderDetailLine(
                label: '升级抵扣',
                value: priceText(order.upgradeCreditAmountCents!)),
          _StoreOrderDetailLine(
              label: '创建时间', value: storeOrderDateText(order.createdAt)),
        ],
      ),
    );
  }
}

class _StoreOrderDetailLine extends StatelessWidget {
  const _StoreOrderDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: const TextStyle(
                    color: keliMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    color: keliInk, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSteps extends StatelessWidget {
  const _CheckoutSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        children: const [
          _CheckoutStep(index: '1', label: '确认订单', active: true),
          _CheckoutConnector(),
          _CheckoutStep(index: '2', label: '选择支付', active: true),
          _CheckoutConnector(),
          _CheckoutStep(index: '3', label: '完成刷新', active: false),
        ],
      ),
    );
  }
}

class _CheckoutStep extends StatelessWidget {
  const _CheckoutStep({
    required this.index,
    required this.label,
    required this.active,
  });

  final String index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active ? keliBlueStrong : const Color(0xFFE8EDF5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(index,
                style: TextStyle(
                    color: active ? Colors.white : keliMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: active ? keliInk : keliMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _CheckoutConnector extends StatelessWidget {
  const _CheckoutConnector();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Divider(height: 1, color: keliLine),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.plan,
    required this.option,
  });

  final StorePlan plan;
  final PlanPeriodOption option;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: keliBlueSoft.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${option.label} · ${monthlyPriceText(option)}',
                        style: const TextStyle(
                            color: keliMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(priceText(option.priceCents),
                  style: const TextStyle(
                      color: keliBlueStrong,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          _CheckoutSummaryLine(label: '可用流量', value: plan.trafficLabel),
          _CheckoutSummaryLine(
              label: '允许设备',
              value: plan.deviceLimit == null || plan.deviceLimit == 0
                  ? '无限制'
                  : '${plan.deviceLimit} 台'),
          _CheckoutSummaryLine(
              label: '最高网速',
              value: plan.speedLimit == null || plan.speedLimit == 0
                  ? '无限制'
                  : '${plan.speedLimit!.toStringAsFixed(0)} Mbps'),
        ],
      ),
    );
  }
}

class _CheckoutSummaryLine extends StatelessWidget {
  const _CheckoutSummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: keliMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: keliInk, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CheckoutOrderBox extends StatelessWidget {
  const _CheckoutOrderBox({required this.tradeNo});

  final String tradeNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 18, color: keliBlueStrong),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              '订单号：$tradeNo',
              style: const TextStyle(
                color: keliInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: '复制订单号',
            onPressed: () => Clipboard.setData(ClipboardData(text: tradeNo)),
            icon: const Icon(Icons.copy_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _UpgradePreviewBox extends StatelessWidget {
  const _UpgradePreviewBox({
    required this.preview,
    required this.loading,
    required this.error,
  });

  final UpgradePreview? preview;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final data = preview;
    if (loading && data == null) {
      return const _CheckoutInfoBox(
        icon: Icons.hourglass_empty_rounded,
        title: '正在预览升级价格',
        message: '客户端正在向面板确认补差价金额和升级资格。',
      );
    }
    if (error != null && error!.isNotEmpty) {
      return _CheckoutInfoBox(
        icon: Icons.error_outline,
        title: '升级不可用',
        message: error!,
      );
    }
    if (data == null) {
      return const _CheckoutInfoBox(
        icon: Icons.info_outline,
        title: '升级预览',
        message: '创建升级订单前会先向面板确认补差价金额。',
      );
    }

    final payable = data.payableAmountCents;
    final target = data.targetPriceCents;
    final credit = data.upgradeCreditAmountCents;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_check_rounded,
                  size: 18, color: keliBlueStrong),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data.sourcePlanName ?? '当前套餐'} → ${data.targetPlanName ?? '目标套餐'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (target != null)
            _CheckoutSummaryLine(label: '目标套餐价格', value: priceText(target)),
          if (credit != null)
            _CheckoutSummaryLine(label: '升级抵扣', value: '-${priceText(credit)}'),
          if (payable != null)
            _CheckoutSummaryLine(label: '本次应付', value: priceText(payable)),
          if (data.reason != null && data.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(data.reason!,
                style: const TextStyle(
                    color: keliMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? keliBlueSoft : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? const Color(0xFFCFE3FF) : keliLineSoft),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? keliBlueStrong : keliMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(method.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text(method.payment,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: keliMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutInfoBox extends StatelessWidget {
  const _CheckoutInfoBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: keliBlueStrong, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(message,
                    style: const TextStyle(
                        color: keliMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutResultBox extends StatelessWidget {
  const _CheckoutResultBox({
    required this.result,
    required this.detail,
    required this.isError,
  });

  final PurchaseResult result;
  final String? detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? keliRed : keliGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                  size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(result.message,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ),
            ],
          ),
          if (result.tradeNo != null) ...[
            const SizedBox(height: 8),
            SelectableText('订单号：${result.tradeNo}',
                style: const TextStyle(
                    color: keliInk, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!,
                style: const TextStyle(
                    color: keliMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

Future<void> showCheckoutQrDialog({
  required BuildContext context,
  required AppController controller,
  required CheckoutQrPayload payload,
  required String? tradeNo,
  required String successMessage,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CheckoutQrDialog(
      controller: controller,
      payload: payload,
      tradeNo: tradeNo,
      successMessage: successMessage,
    ),
  );
}

class _CheckoutQrDialog extends StatefulWidget {
  const _CheckoutQrDialog({
    required this.controller,
    required this.payload,
    required this.tradeNo,
    required this.successMessage,
  });

  final AppController controller;
  final CheckoutQrPayload payload;
  final String? tradeNo;
  final String successMessage;

  @override
  State<_CheckoutQrDialog> createState() => _CheckoutQrDialogState();
}

class _CheckoutQrDialogState extends State<_CheckoutQrDialog> {
  bool checking = false;
  String? statusText;

  Future<void> copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label已复制')));
  }

  Future<void> openPaymentUrl() async {
    final url = widget.payload.paymentUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    final opened = await openExternalUrl(url);
    if (!mounted) {
      return;
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('支付链接打开失败，已复制')));
    }
  }

  Future<void> checkStatus() async {
    final tradeNo = widget.tradeNo;
    if (tradeNo == null || tradeNo.isEmpty || checking) {
      return;
    }
    setState(() {
      checking = true;
      statusText = null;
    });
    try {
      final status = await widget.controller.checkStoreOrder(tradeNo);
      if (!mounted) {
        return;
      }
      if (status == 3) {
        await widget.controller.bootstrap();
        await widget.controller.refreshOrders();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.successMessage)));
        Navigator.pop(context);
      } else {
        setState(() => statusText = '订单尚未完成支付，当前状态码：$status');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => statusText = '查询失败：$error');
    } finally {
      if (mounted) {
        setState(() => checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final expiry = qrExpiryText(payload.expirationTime);
    final amountText = qrAmountText(payload);
    final primaryCopy =
        payload.address?.isNotEmpty == true ? payload.address! : payload.qrData;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: keliBlueSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded,
                              color: keliBlueStrong, size: 21),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('扫码支付',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 2),
                              Text('使用对应钱包扫码或复制地址完成付款',
                                  style: TextStyle(
                                      color: keliMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: keliLine),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: payload.qrData,
                          version: QrVersions.auto,
                          size: 220,
                          gapless: true,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (payload.network != null ||
                        payload.currency != null ||
                        expiry != null) ...[
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tiles = <Widget>[
                            if (payload.network != null)
                              _QrMetaTile(label: '网络', value: payload.network!),
                            if (payload.currency != null)
                              _QrMetaTile(
                                  label: '币种', value: payload.currency!),
                            if (expiry != null)
                              _QrMetaTile(label: '有效期', value: expiry),
                          ];
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tile in tiles)
                                SizedBox(
                                  width: constraints.maxWidth >= 420
                                      ? (constraints.maxWidth - 16) / 3
                                      : constraints.maxWidth,
                                  child: tile,
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (amountText != null) ...[
                      const SizedBox(height: 12),
                      _QrInfoRow(
                        label: '支付金额',
                        value: amountText,
                        onCopy: () => copyText(amountText, '支付金额'),
                      ),
                    ],
                    if (payload.address != null &&
                        payload.address!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _QrInfoRow(
                        label: '收款地址',
                        value: payload.address!,
                        dense: true,
                        onCopy: () => copyText(payload.address!, '收款地址'),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      _QrInfoRow(
                        label: '支付内容',
                        value: payload.qrData,
                        dense: true,
                        onCopy: () => copyText(payload.qrData, '支付内容'),
                      ),
                    ],
                    if (payload.paymentUrl != null &&
                        payload.paymentUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const _CheckoutInfoBox(
                        icon: Icons.info_outline,
                        title: '移动端支付',
                        message: '也可以打开支付链接，在手机钱包或浏览器中继续完成支付。',
                      ),
                    ],
                    if (statusText != null) ...[
                      const SizedBox(height: 10),
                      _CheckoutInfoBox(
                        icon: Icons.fact_check_outlined,
                        title: '支付状态',
                        message: statusText!,
                      ),
                    ],
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final closeButton = OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        );
                        final copyButton = OutlinedButton.icon(
                          onPressed: () => copyText(primaryCopy, '支付信息'),
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          label: const Text('复制'),
                        );
                        final openButton = payload.paymentUrl != null &&
                                payload.paymentUrl!.isNotEmpty
                            ? OutlinedButton.icon(
                                onPressed: openPaymentUrl,
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 17),
                                label: const Text('打开链接'),
                              )
                            : null;
                        final paidButton = FilledButton.icon(
                          onPressed: widget.tradeNo == null || checking
                              ? null
                              : checkStatus,
                          icon: checking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline,
                                  size: 17),
                          label: Text(checking ? '查询中' : '我已支付'),
                        );

                        if (constraints.maxWidth < 430) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              paidButton,
                              const SizedBox(height: 8),
                              if (openButton != null) ...[
                                openButton,
                                const SizedBox(height: 8),
                              ],
                              copyButton,
                              const SizedBox(height: 8),
                              closeButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: closeButton),
                            const SizedBox(width: 10),
                            Expanded(child: copyButton),
                            if (openButton != null) ...[
                              const SizedBox(width: 10),
                              Expanded(child: openButton),
                            ],
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: paidButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrMetaTile extends StatelessWidget {
  const _QrMetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: keliMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _QrInfoRow extends StatelessWidget {
  const _QrInfoRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.dense = false,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: keliMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                SelectableText(value,
                    style: TextStyle(
                        color: keliInk,
                        fontSize: dense ? 12 : 14,
                        fontWeight: dense ? FontWeight.w700 : FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('复制'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(74, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreOrdersPanel extends StatelessWidget {
  const _StoreOrdersPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final orders = controller.storeOrders;
    final pending = controller.pendingOrder;
    return SizedBox(
      width: double.infinity,
      child: KeliCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('订单',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isRefreshingStore
                      ? null
                      : () => controller.refreshStore(),
                  icon: controller.isRefreshingStore
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 17),
                  label: Text(controller.isRefreshingStore ? '刷新中' : '刷新'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (controller.isRefreshingStore && orders.isEmpty)
              const _StoreLoadingBox(message: '正在加载订单')
            else if (orders.isEmpty)
              const _EmptyStoreBox(message: '暂无订单记录')
            else ...[
              if (pending != null) ...[
                _PendingOrderBanner(
                  order: pending,
                  onPay: () => showExistingOrderPaymentDialog(
                    context: context,
                    controller: controller,
                    order: pending,
                  ),
                  onCancel: () =>
                      confirmCancelStoreOrder(context, controller, pending),
                ),
                const SizedBox(height: 12),
              ],
              for (final order in orders) ...[
                _StoreOrderCard(
                  order: order,
                  onView: () => showStoreOrderDetailDialog(context, order),
                  onPay: order.isPending
                      ? () => showExistingOrderPaymentDialog(
                            context: context,
                            controller: controller,
                            order: order,
                          )
                      : null,
                  onCancel: order.isPending
                      ? () =>
                          confirmCancelStoreOrder(context, controller, order)
                      : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreLoadingBox extends StatelessWidget {
  const _StoreLoadingBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(color: keliMuted)),
        ],
      ),
    );
  }
}

class _PendingOrderBanner extends StatelessWidget {
  const _PendingOrderBanner({
    required this.order,
    required this.onPay,
    required this.onCancel,
  });

  final StoreOrder order;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: keliOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child:
                const Icon(Icons.schedule_rounded, color: keliOrange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已有待支付订单',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  '${storeOrderPlanName(order)} · ${priceText(order.totalAmountCents)} · ${order.tradeNo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: keliMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: onCancel, child: const Text('取消')),
          const SizedBox(width: 8),
          FilledButton(onPressed: onPay, child: const Text('去支付')),
        ],
      ),
    );
  }
}

class _StoreOrderCard extends StatelessWidget {
  const _StoreOrderCard({
    required this.order,
    required this.onView,
    required this.onPay,
    required this.onCancel,
  });

  final StoreOrder order;
  final VoidCallback onView;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      storeOrderPlanName(order),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: [
                  _OrderMeta(
                      icon: Icons.event_note,
                      text: orderPeriodText(order.period)),
                  _OrderMeta(
                      icon: Icons.payments_outlined,
                      text: priceText(order.totalAmountCents)),
                  _OrderMeta(
                      icon: Icons.access_time_rounded,
                      text: storeOrderDateText(order.createdAt)),
                ],
              ),
              const SizedBox(height: 9),
              SelectableText(
                order.tradeNo,
                style: const TextStyle(
                    color: keliMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          );
          final actions = Wrap(
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('查看'),
              ),
              if (onPay != null)
                FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payment_outlined, size: 16),
                  label: const Text('支付'),
                ),
              if (onCancel != null)
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('取消'),
                  style: OutlinedButton.styleFrom(foregroundColor: keliRed),
                ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        orderStatusText(status),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: keliMuted),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                color: keliMuted, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EmptyStoreBox extends StatelessWidget {
  const _EmptyStoreBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: keliLineSoft),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: keliMuted)),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(message,
          style: const TextStyle(color: keliRed, fontWeight: FontWeight.w800)),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= keliDesktopBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(title: '设置', subtitle: '代理模式、启动项和核心参数'),
        const SizedBox(height: 16),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SettingsModePanel(controller: controller)),
              const SizedBox(width: 12),
              const Expanded(child: _SettingsGeneralPanel()),
            ],
          )
        else ...[
          _SettingsModePanel(controller: controller),
          const SizedBox(height: 12),
          const _SettingsGeneralPanel(),
        ],
        const SizedBox(height: 12),
        KeliCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('核心与诊断',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const SettingsTile(
                  icon: Icons.dns_outlined, title: 'DNS 模式', value: '自动'),
              const CardDivider(),
              const SettingsTile(
                  icon: Icons.memory_outlined,
                  title: 'sing-box 核心',
                  value: '内置管理'),
              const CardDivider(),
              const SettingsTile(
                  icon: Icons.article_outlined, title: '日志等级', value: 'info'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('退出登录'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsModePanel extends StatelessWidget {
  const _SettingsModePanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KeliCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('代理模式',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SegmentedButton<ProxyMode>(
            segments: const [
              ButtonSegment(
                  value: ProxyMode.system,
                  icon: Icon(Icons.settings_ethernet),
                  label: Text('系统代理')),
              ButtonSegment(
                  value: ProxyMode.tun,
                  icon: Icon(Icons.shield_outlined),
                  label: Text('TUN模式')),
              ButtonSegment(
                  value: ProxyMode.vpn,
                  icon: Icon(Icons.vpn_lock_outlined),
                  label: Text('VPN模式')),
            ],
            selected: {controller.proxyMode},
            onSelectionChanged: (value) => controller.selectMode(value.first),
          ),
          const SizedBox(height: 12),
          ModeToggleLine(
            icon: Icons.monitor_outlined,
            title: '系统代理',
            value: controller.proxyMode == ProxyMode.system,
            onChanged: (_) => controller.selectMode(ProxyMode.system),
          ),
          const SizedBox(height: 8),
          ModeToggleLine(
            icon: Icons.shield_outlined,
            title: 'TUN模式',
            value: controller.proxyMode == ProxyMode.tun,
            onChanged: (_) => controller.selectMode(ProxyMode.tun),
          ),
        ],
      ),
    );
  }
}

class _SettingsGeneralPanel extends StatelessWidget {
  const _SettingsGeneralPanel();

  @override
  Widget build(BuildContext context) {
    return const KeliCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('常规设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 10),
          SettingsSwitch(
              title: '开机自启', subtitle: '登录系统后自动启动 Keli Client', value: false),
          CardDivider(),
          SettingsSwitch(
              title: '启动后自动连接', subtitle: '打开客户端后连接上次使用节点', value: true),
          CardDivider(),
          SettingsSwitch(title: '绕过局域网', subtitle: '局域网地址不进入代理核心', value: true),
          CardDivider(),
          SettingsSwitch(title: '绕过中国大陆', subtitle: '大陆常用地址直连', value: true),
        ],
      ),
    );
  }
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) {
      return;
    }
    loaded = true;
    Future<void>.microtask(() =>
        AppControllerScope.of(context).refreshDiagnostics(logResult: false));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final logs = controller.logs;
    final diagnostics = controller.diagnostics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: '诊断',
          subtitle: '核心、配置、系统代理和最近错误',
          trailing: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: controller.isRefreshingDiagnostics
                    ? null
                    : controller.refreshDiagnostics,
                icon: controller.isRefreshingDiagnostics
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: Text(controller.isRefreshingDiagnostics ? '刷新中' : '刷新'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: controller.diagnosticReport()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('诊断信息已复制')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制诊断'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (diagnostics != null) ...[
          _MetricGrid(
            items: [
              MetricItem(
                  label: '核心进程',
                  value: diagnostics.processRunning ? '运行中' : '未运行'),
              MetricItem(label: '本地代理', value: diagnostics.localProxyDisplay),
              MetricItem(
                  label: '系统代理',
                  value: diagnostics.systemProxyEnabled ? '已启用' : '未启用'),
              MetricItem(label: '配置检查', value: diagnostics.configCheckStatus),
            ],
          ),
          const SizedBox(height: 18),
          KeliCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('运行信息',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DiagnosticRow(label: '运行目录', value: diagnostics.runtimeRoot),
                DiagnosticRow(
                    label: '核心文件',
                    value:
                        diagnostics.coreExists ? diagnostics.corePath : '未下载'),
                DiagnosticRow(
                    label: '配置文件',
                    value: diagnostics.configExists
                        ? diagnostics.configPath
                        : '未生成'),
                DiagnosticRow(
                    label: '日志文件',
                    value: diagnostics.logExists ? diagnostics.logPath : '未生成'),
                DiagnosticRow(
                    label: '系统代理', value: diagnostics.systemProxyServer ?? '-'),
                DiagnosticRow(
                    label: '更新时间', value: timeText(diagnostics.updatedAt)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KeliCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('配置检查',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DiagnosticTextBlock(
                  text: diagnostics.configCheckOutput.isEmpty
                      ? diagnostics.configCheckStatus
                      : diagnostics.configCheckOutput,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          const KeliCard(
            child: Row(
              children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('正在读取诊断信息'),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (diagnostics != null && diagnostics.logTail.isNotEmpty) ...[
          KeliCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('核心日志尾部',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DiagnosticTextBlock(text: diagnostics.logTail.join('\n')),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        KeliCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final entry in logs) _LogEntryRow(entry: entry),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无客户端日志', style: TextStyle(color: keliMuted)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = logSummaryText(entry.message);
    final detail = logDetailText(entry.message, title);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: keliLineSoft))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(timeText(entry.time),
                style: const TextStyle(color: keliMuted, fontSize: 12)),
          ),
          _LogLevelBadge(level: entry.level),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: keliMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '复制完整日志',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: entry.message));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('日志已复制')));
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _LogLevelBadge extends StatelessWidget {
  const _LogLevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'ERROR' => keliRed,
      'WARN' => keliOrange,
      _ => keliBlueStrong,
    };
    return Container(
      width: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(level,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class DiagnosticRow extends StatelessWidget {
  const DiagnosticRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 82,
              child: Text(label, style: const TextStyle(color: keliMuted))),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class DiagnosticTextBlock extends StatelessWidget {
  const DiagnosticTextBlock({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            color: Color(0xFFE5E7EB),
            fontFamily: 'Consolas',
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({
    required this.label,
    required this.value,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 88,
              child: Text(label,
                  style: const TextStyle(color: keliMuted, fontSize: 12))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? keliInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class ModeToggleLine extends StatelessWidget {
  const ModeToggleLine({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: value ? keliBlueSoft : const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: value ? const Color(0xFFD8E8FF) : keliLineSoft),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? keliBlueStrong : keliMuted, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          SizedBox(
            width: 48,
            height: 28,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: keliMuted)),
          ],
        );
        if (trailing == null) {
          return titleBlock;
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: trailing!),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleBlock),
            trailing!,
          ],
        );
      },
    );
  }
}

class KeliCard extends StatelessWidget {
  const KeliCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: keliPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: keliLineSoft),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.026),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class CardDivider extends StatelessWidget {
  const CardDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: keliLineSoft);
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: keliSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: keliLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: keliMuted),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class MetricItem {
  const MetricItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 360 ? 2 : 1;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 10) / columns,
                  child: MetricTile(item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile(this.item, {super.key});

  final MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: keliBlueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.analytics_outlined,
                size: 18, color: keliBlueStrong),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(color: keliMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(item.value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CopyRow extends StatelessWidget {
  const CopyRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: keliLineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: keliBlueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child:
                const Icon(Icons.link_rounded, size: 18, color: keliBlueStrong),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 74,
              child: Text(label,
                  style: const TextStyle(color: keliMuted, fontSize: 12))),
          Expanded(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已复制')));
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制',
          ),
        ],
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: keliMuted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 28,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(value: value, onChanged: (_) {}),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: keliBlueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: keliBlueStrong),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          Text(value,
              style: const TextStyle(
                  color: keliMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: keliMuted),
        ],
      ),
    );
  }
}

String profileInitials(AppProfile? profile) {
  final raw = (profile?.email.split('@').first ?? 'K').trim();
  if (raw.isEmpty) {
    return 'K';
  }
  final letters = RegExp(r'[A-Za-z0-9]+')
      .allMatches(raw)
      .map((match) => match.group(0) ?? '')
      .join();
  final source = letters.isNotEmpty ? letters : raw;
  return source.runes.take(2).map(String.fromCharCode).join().toUpperCase();
}

String subscriptionBadgeText(AppProfile? profile) {
  if (profile == null) {
    return '未登录';
  }
  return profile.hasActiveSubscription ? '有效' : '未订阅';
}

Color subscriptionBadgeColor(AppProfile? profile) {
  if (profile == null) {
    return keliMuted;
  }
  return profile.hasActiveSubscription ? keliGreen : keliOrange;
}

String profileMetaText(AppProfile profile) {
  final parts = <String>[
    '套餐: ${profile.planName.trim().isEmpty ? '未订阅' : profile.planName}',
    '设备限制: ${deviceLimitText(profile.deviceLimit)}',
    '速率: ${speedLimitText(profile.speedLimit)}',
  ];
  return parts.join('    ');
}

String deviceLimitText(int? value) {
  if (value == null || value <= 0) {
    return '无限制';
  }
  return '$value 台';
}

String speedLimitText(double? value) {
  if (value == null || value <= 0) {
    return '无限制';
  }
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text Mbps';
}

String normalizedLogMessage(String message) {
  return message.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String logSummaryText(String message) {
  final normalized = normalizedLogMessage(message);
  if (normalized.isEmpty) {
    return '-';
  }
  final latencyFailureIndex = normalized.indexOf(' 测速失败:');
  if (normalized.startsWith('节点 ') && latencyFailureIndex > 0) {
    return normalized.substring(0, latencyFailureIndex + ' 测速失败'.length);
  }
  final colonIndex = normalized.indexOf(': ');
  if (colonIndex > 0 && colonIndex <= 46) {
    return normalized.substring(0, colonIndex);
  }
  if (normalized.length > 86) {
    return '${normalized.substring(0, 86)}...';
  }
  return normalized;
}

String logDetailText(String message, String summary) {
  final normalized = normalizedLogMessage(message);
  if (normalized.isEmpty || normalized == summary) {
    return '';
  }
  var detail = '';
  if (normalized.startsWith(summary)) {
    detail = normalized.substring(summary.length).trimLeft();
    if (detail.startsWith(':')) {
      detail = detail.substring(1).trimLeft();
    }
  } else {
    final colonIndex = normalized.indexOf(': ');
    if (colonIndex > 0) {
      detail = normalized.substring(colonIndex + 2).trimLeft();
    }
  }
  if (detail.length > 128) {
    return '${detail.substring(0, 128)}...';
  }
  return detail;
}

String profileResetText(AppProfile profile) {
  final nextResetAt = profile.nextResetAt;
  if (nextResetAt != null) {
    return dateText(nextResetAt);
  }
  if (profile.resetDay > 0) {
    return '${profile.resetDay} 天';
  }
  return '-';
}

String latencyText(int? latencyMs) {
  if (latencyMs == null) {
    return '未测';
  }
  return '${latencyMs}ms';
}

String nodeLatencyText(AppController controller, ProxyNode? node) {
  if (node == null) {
    return '-';
  }
  if (node.latencyMs != null) {
    return latencyText(node.latencyMs);
  }
  if (controller.isTestingLatency && controller.latencyAttemptedFor(node.id)) {
    return '测速中';
  }
  if (controller.latencyAttemptedFor(node.id)) {
    return '超时';
  }
  return '未测';
}

List<PlanPeriodOption> recurringOptions(StorePlan plan) {
  return plan.periodOptions
      .where((option) =>
          option.period != 'onetime_price' && option.period != 'reset_price')
      .toList();
}

List<PlanPeriodOption> trafficOptions(StorePlan plan) {
  return plan.periodOptions
      .where((option) =>
          option.period == 'onetime_price' || option.period == 'reset_price')
      .toList();
}

bool isTrafficPackPlan(StorePlan plan) {
  final hasRecurring = recurringOptions(plan).isNotEmpty;
  final hasTraffic = trafficOptions(plan).isNotEmpty;
  if (!hasRecurring && hasTraffic) {
    return true;
  }

  final text = '${plan.name} ${plan.content}'.toLowerCase();
  final keyword = RegExp(
    r'按量|流量包|一次性|不续费|临时|体验|pay.*go|traffic.*pack|one.*time',
    caseSensitive: false,
  );
  return hasTraffic && keyword.hasMatch(text);
}

StorePlan? selectedRecurringPlan(List<StorePlan> plans, int? selectedPlanId) {
  if (plans.isEmpty) {
    return null;
  }
  if (selectedPlanId != null) {
    for (final plan in plans) {
      if (plan.id == selectedPlanId) {
        return plan;
      }
    }
  }
  return plans.first;
}

StorePlan? selectedStorePlan(List<StorePlan> plans, int? selectedPlanId) {
  if (plans.isEmpty) {
    return null;
  }
  if (selectedPlanId != null) {
    for (final plan in plans) {
      if (plan.id == selectedPlanId) {
        return plan;
      }
    }
  }
  return plans.first;
}

PlanPeriodOption? firstTrafficOption(StorePlan plan) {
  final options = trafficOptions(plan);
  if (options.isEmpty) {
    return null;
  }
  return options.first;
}

String monthlyPriceText(PlanPeriodOption option) {
  if (option.period == 'onetime_price') {
    return '一次性购买';
  }
  if (option.period == 'reset_price') {
    return '重置流量';
  }
  if (option.months <= 1) {
    return '按月续费';
  }

  final monthlyCents = (option.priceCents / option.months).round();
  return '约 ${priceText(monthlyCents)}/月';
}

String monthlyPriceNumberText(PlanPeriodOption option) {
  if (option.months <= 1) {
    return priceNumberText(option.priceCents);
  }
  return priceNumberText((option.priceCents / option.months).round());
}

String priceNumberText(int cents) {
  final value = cents / 100;
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

Future<void> handlePlanPurchase(
  BuildContext context,
  AppController controller,
  StorePlan plan,
  PlanPeriodOption option,
) async {
  final result = await controller.purchasePlan(plan, option);
  if (result.copyText != null) {
    await Clipboard.setData(ClipboardData(text: result.copyText!));
  }
  if (result.externalUrl != null && context.mounted) {
    final opened = await openExternalUrl(result.externalUrl!);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: result.externalUrl!));
    }
  }
  if (result.qrPayload != null && context.mounted) {
    unawaited(showCheckoutQrDialog(
      context: context,
      controller: controller,
      payload: result.qrPayload!,
      tradeNo: result.tradeNo,
      successMessage: '支付成功，套餐已刷新',
    ));
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }
}

String priceText(int cents) {
  final value = cents / 100;
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '¥$text';
}

String storeOrderPlanName(StoreOrder order) {
  if (order.upgradeTargetPlanName != null &&
      order.upgradeTargetPlanName!.isNotEmpty) {
    return order.upgradeTargetPlanName!;
  }
  if (order.planName != null && order.planName!.isNotEmpty) {
    return order.planName!;
  }
  if (order.isRecharge) {
    return '余额充值';
  }
  return '套餐订单';
}

String orderPeriodText(String period) {
  return switch (period) {
    'month_price' => '月付',
    'quarter_price' => '季付',
    'half_year_price' => '半年',
    'year_price' => '年付',
    'two_year_price' => '两年',
    'three_year_price' => '三年',
    'onetime_price' => '一次性',
    'reset_price' => '重置流量',
    'deposit' || 'recharge' => '余额充值',
    _ => period.isEmpty ? '-' : period,
  };
}

String orderStatusText(int status) {
  return switch (status) {
    0 => '待支付',
    1 => '处理中',
    2 => '已取消',
    3 => '已完成',
    4 => '已退款',
    _ => '未知($status)',
  };
}

Color orderStatusColor(int status) {
  return switch (status) {
    0 => keliOrange,
    1 => keliBlueStrong,
    2 => keliMuted,
    3 => keliGreen,
    4 => keliRed,
    _ => keliMuted,
  };
}

String storeOrderDateText(DateTime? value) {
  if (value == null) {
    return '-';
  }
  return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

Future<bool> openExternalUrl(String url) async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run(
          'rundll32.exe', ['url.dll,FileProtocolHandler', url]);
      if (result.exitCode == 0) {
        return true;
      }
      final fallback = await Process.run('explorer.exe', [url]);
      return fallback.exitCode == 0;
    } else if (Platform.isMacOS) {
      final result = await Process.run('open', [url]);
      return result.exitCode == 0;
    } else if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [url]);
      return result.exitCode == 0;
    }
  } catch (_) {
    return false;
  }
  return false;
}

String? qrAmountText(CheckoutQrPayload payload) {
  final amount = payload.amount;
  final currency = payload.currency;
  final fiatAmount = payload.fiatAmount;
  final fiat = payload.fiat;
  if (amount == null || amount.isEmpty) {
    if (fiatAmount == null || fiatAmount.isEmpty) {
      return null;
    }
    return fiat == null || fiat.isEmpty ? fiatAmount : '$fiatAmount $fiat';
  }
  final primary =
      currency == null || currency.isEmpty ? amount : '$amount $currency';
  if (fiatAmount == null || fiatAmount.isEmpty) {
    return primary;
  }
  final fiatText =
      fiat == null || fiat.isEmpty ? fiatAmount : '$fiatAmount $fiat';
  return '$primary  ≈ $fiatText';
}

String? qrExpiryText(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final seconds = value > 10000000000
      ? value ~/ 1000 - nowSeconds
      : value > 1000000000
          ? value - nowSeconds
          : value;
  if (seconds <= 0) {
    return '即将过期';
  }
  final minutes = seconds ~/ 60;
  final restSeconds = seconds % 60;
  if (minutes <= 0) {
    return '$restSeconds 秒';
  }
  if (minutes < 60) {
    return '$minutes 分钟';
  }
  final hours = minutes ~/ 60;
  final restMinutes = minutes % 60;
  return restMinutes == 0 ? '$hours 小时' : '$hours 小时 $restMinutes 分钟';
}

Color latencyStatusColor(int? latencyMs) {
  if (latencyMs == null) {
    return keliMuted;
  }
  if (latencyMs > 1000) {
    return keliRed;
  }
  if (latencyMs >= 300) {
    return keliOrange;
  }
  return keliGreen;
}

Color nodeLatencyStatusColor(AppController controller, ProxyNode? node) {
  if (node == null) {
    return keliMuted;
  }
  if (node.latencyMs != null) {
    return latencyStatusColor(node.latencyMs);
  }
  if (controller.isTestingLatency && controller.latencyAttemptedFor(node.id)) {
    return keliBlueStrong;
  }
  if (controller.latencyAttemptedFor(node.id)) {
    return keliRed;
  }
  return keliMuted;
}

String timeText(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}

String dateText(DateTime time) {
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}

String daysLeftText(DateTime expireAt) {
  final days = expireAt.difference(DateTime.now()).inDays;
  if (days < 0) {
    return '已到期';
  }
  return '剩余 $days 天';
}

String durationClockText(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String compactMetricLabel(String label) {
  return switch (label) {
    '下载速度' => '下载',
    '上传速度' => '上传',
    '本次用量' => '用量',
    '连接时长' => '时长',
    _ => label,
  };
}
