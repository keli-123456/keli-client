import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../state/app_controller.dart';
import '../theme.dart';

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

        final isDesktop = constraints.maxWidth >= 900;
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
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
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
        final horizontalPadding = widget.isDesktop ? 20.0 : 14.0;
        final topPadding = widget.isDesktop ? 12.0 : 12.0;
        final bottomPadding = widget.isDesktop ? 8.0 : 20.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final contentWidth = availableWidth > 1040 ? 1040.0 : availableWidth;

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
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: contentWidth < 0 ? 0 : contentWidth,
                    child: child,
                  ),
                ),
              ),
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
            Text('v1.0.0',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: 4),
        Text('已是最新版', style: TextStyle(color: keliMuted, fontSize: 11)),
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
          _MobileHeader(profile: profile),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  _ConnectPanel(node: node),
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
                  _ModeAndRoutePanel(),
                  const SizedBox(height: 12),
                  const _QuickActionsPanel(),
                ],
              ),
            ),
          ],
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
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: keliBlueSoft,
                      child: Text('KE',
                          style: TextStyle(
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
                              const _MiniBadge(text: '高级版', color: keliOrange),
                            ],
                          ),
                          const SizedBox(height: 7),
                          const Text('UID: 10086    设备数: 1/5',
                              style: TextStyle(color: keliMuted, fontSize: 12)),
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
  const _MobileHeader({required this.profile});

  final AppProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
            child: Text('Keli Client',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        IconButton(
            onPressed: () {}, icon: const Icon(Icons.notifications_none)),
      ],
    );
  }
}

class _ConnectPanel extends StatelessWidget {
  const _ConnectPanel({required this.node, this.compact = false});

  final ProxyNode? node;
  final bool compact;

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

    return KeliCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: SizedBox(
        height: compact ? null : 356,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!compact)
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
            if (!compact) const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: busy
                  ? null
                  : connected
                      ? controller.disconnect
                      : controller.connect,
              child: SizedBox(
                width: compact ? 186 : 184,
                height: compact ? 186 : 184,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: compact ? 186 : 184,
                      height: compact ? 186 : 184,
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
                      width: compact ? 168 : 166,
                      height: compact ? 168 : 166,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFD),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: compact ? 132 : 128,
                      height: compact ? 132 : 128,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: keliLineSoft),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(node.protocol,
                    style: const TextStyle(color: keliMuted, fontSize: 12)),
              ],
            ),
          ),
          const _MiniBadge(text: '自动选择', color: keliGreen),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: keliMuted, size: 18),
        ],
      ),
    );
  }
}

class _CurrentNodePanel extends StatelessWidget {
  const _CurrentNodePanel({required this.node});

  final ProxyNode? node;

  @override
  Widget build(BuildContext context) {
    final n = node;
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: keliBlueSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD8E8FF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: keliBlueStrong,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child:
                      const Icon(Icons.public, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n?.name ?? '未选择节点',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(n?.protocol ?? '-',
                          style:
                              const TextStyle(color: keliMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const _MiniBadge(text: '自动选择', color: keliGreen),
              ],
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
                      value: latencyText(n?.latencyMs),
                      color: latencyStatusColor(n?.latencyMs))),
              const SizedBox(width: 8),
              Expanded(
                  child: _NodeStatCell(
                      label: '倍率',
                      value:
                          n == null ? '-' : '${n.rate.toStringAsFixed(1)}x')),
            ],
          ),
        ],
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
  const _ModeAndRoutePanel();

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
          const SizedBox(height: 9),
          const Divider(height: 1),
          const SizedBox(height: 7),
          const Text('分流设置',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const DetailLine(label: '绕过中国大陆', value: '启用', color: keliGreen),
          const DetailLine(label: '绕过局域网', value: '启用', color: keliGreen),
          const DetailLine(label: 'DNS', value: '自动 (1.1.1.1)'),
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

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel();

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    return KeliCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快捷操作',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.hub_outlined,
                  title: '节点',
                  onTap: () => controller.selectPage(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.speed_outlined,
                  title: '测速',
                  onTap: controller.testAllLatency,
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

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 16, color: keliMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
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
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: keliBlueSoft,
                  child: Text('KE',
                      style: TextStyle(
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
                const _MiniBadge(text: '高级版', color: keliOrange),
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
              MetricItem(label: '重置', value: '${profile!.resetDay} 天'),
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
    final active = controller.connectionState == ConnectionStateKind.connected;
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
          value: active ? '256.34 MB' : '0 MB',
          icon: Icons.donut_large_rounded,
          color: const Color(0xFF8B5CF6)),
      _RuntimeMetricData(
          label: '连接时长',
          value: durationText,
          icon: Icons.schedule_rounded,
          color: keliOrange),
    ];

    return KeliCard(
      padding: const EdgeInsets.all(14),
      child: isDesktop
          ? Row(
              children: items
                  .map((item) => Expanded(child: _RuntimeMetricTile(item)))
                  .toList())
          : Row(
              children: items
                  .map((item) =>
                      Expanded(child: _CompactRuntimeMetricTile(item)))
                  .toList(),
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
  const _CompactRuntimeMetricTile(this.item);

  final _RuntimeMetricData item;

  @override
  Widget build(BuildContext context) {
    final parts = item.value.split(' ');
    final value = parts.first;
    final unit = parts.length > 1 ? parts.skip(1).join(' ') : '';
    final label = compactMetricLabel(item.label);
    return Container(
      height: 78,
      margin: const EdgeInsets.all(3),
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
            onPressed: controller.testAllLatency,
            icon: const Icon(Icons.speed, size: 18),
            label: const Text('全部测速'),
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
    final latencyColor = latencyStatusColor(node.latencyMs);
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
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color:
                            selected ? keliBlueStrong : const Color(0xFFF2F5F9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.public,
                          color: selected ? Colors.white : keliMuted, size: 18),
                    ),
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
                  latencyText(node.latencyMs),
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? keliBlueStrong : const Color(0xFFF2F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.public,
                  color: selected ? Colors.white : keliMuted, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name,
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
                latencyText(node.latencyMs),
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

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final profile = controller.profile;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: '商店',
          subtitle: '套餐、流量和续费',
          trailing: isDesktop
              ? OutlinedButton.icon(
                  onPressed: () => controller.bootstrap(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新套餐'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _CurrentPlanPanel(profile: profile)),
              const SizedBox(width: 12),
              Expanded(
                  flex: 4, child: _StoreActionsPanel(controller: controller)),
            ],
          )
        else ...[
          _CurrentPlanPanel(profile: profile),
          const SizedBox(height: 12),
          _StoreActionsPanel(controller: controller),
        ],
        const SizedBox(height: 12),
        _StoreFeatureGrid(controller: controller),
      ],
    );
  }
}

class _CurrentPlanPanel extends StatelessWidget {
  const _CurrentPlanPanel({required this.profile});

  final AppProfile? profile;

  @override
  Widget build(BuildContext context) {
    final remaining = profile?.remainingTrafficGb.toStringAsFixed(2) ?? '-';
    final total = profile == null
        ? '-'
        : '${profile!.totalTrafficGb.toStringAsFixed(2)} GB';
    final used = profile == null
        ? '-'
        : '${profile!.usedTrafficGb.toStringAsFixed(2)} GB';
    final expire = profile == null ? '-' : dateText(profile!.expireAt);
    return KeliCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: keliBlueSoft,
                child: Text('KE',
                    style: TextStyle(
                        color: keliBlueStrong, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.email ?? '未登录',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(profile?.planName ?? '无套餐',
                        style: const TextStyle(color: keliMuted, fontSize: 12)),
                  ],
                ),
              ),
              const _MiniBadge(text: '当前套餐', color: keliOrange),
            ],
          ),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: remaining,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900)),
                TextSpan(
                    text: ' GB / $total',
                    style: const TextStyle(
                        color: keliMuted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: profile?.usageRatio ?? 0,
              backgroundColor: const Color(0xFFE8EDF5),
              color: keliBlueStrong,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _NodeStatCell(label: '已用', value: used)),
              const SizedBox(width: 8),
              Expanded(child: _NodeStatCell(label: '到期', value: expire)),
              const SizedBox(width: 8),
              Expanded(
                  child: _NodeStatCell(
                      label: '重置',
                      value: profile == null ? '-' : '${profile!.resetDay} 天')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreActionsPanel extends StatelessWidget {
  const _StoreActionsPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KeliCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('套餐中心',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('购买、升级和续费都在面板商店完成',
              style: TextStyle(color: keliMuted, fontSize: 12)),
          const SizedBox(height: 12),
          _StoreActionRow(
            icon: Icons.update_outlined,
            title: '续费当前套餐',
            subtitle: '保持现有节点和套餐权益',
            onPressed: () => openStore(context, controller),
          ),
          const SizedBox(height: 8),
          _StoreActionRow(
            icon: Icons.upgrade_outlined,
            title: '升级套餐',
            subtitle: '按面板当前可售套餐为准',
            onPressed: () => openStore(context, controller),
          ),
          const SizedBox(height: 8),
          _StoreActionRow(
            icon: Icons.add_chart_outlined,
            title: '购买流量包',
            subtitle: '适合临时补充可用流量',
            onPressed: () => openStore(context, controller),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openStore(context, controller),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('打开面板商店'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreActionRow extends StatelessWidget {
  const _StoreActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFBFCFE),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
                child: Icon(icon, size: 18, color: keliBlueStrong),
              ),
              const SizedBox(width: 10),
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
              const Icon(Icons.chevron_right, size: 18, color: keliMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreFeatureGrid extends StatelessWidget {
  const _StoreFeatureGrid({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StoreFeatureItem(
        icon: Icons.workspace_premium_outlined,
        title: '套餐权益',
        value: controller.profile?.planName ?? '未订阅',
        accent: keliOrange,
      ),
      _StoreFeatureItem(
        icon: Icons.public_outlined,
        title: '可用节点',
        value: '${controller.nodes.length} 个',
        accent: keliBlueStrong,
      ),
      _StoreFeatureItem(
        icon: Icons.calendar_month_outlined,
        title: '到期时间',
        value: controller.profile == null
            ? '-'
            : dateText(controller.profile!.expireAt),
        accent: keliGreen,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _StoreFeatureCard(item: item)),
          ],
        );
      },
    );
  }
}

class _StoreFeatureItem {
  const _StoreFeatureItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;
}

class _StoreFeatureCard extends StatelessWidget {
  const _StoreFeatureCard({required this.item});

  final _StoreFeatureItem item;

  @override
  Widget build(BuildContext context) {
    return KeliCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 20, color: item.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(color: keliMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(item.value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
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
              for (final entry in logs)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: keliLineSoft))),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 76,
                          child: Text(timeText(entry.time),
                              style: const TextStyle(
                                  color: keliMuted, fontSize: 12))),
                      _LogLevelBadge(level: entry.level),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(entry.message,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
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

class _LogLevelBadge extends StatelessWidget {
  const _LogLevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final isError = level == 'ERROR';
    final color = isError ? keliRed : keliBlueStrong;
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: keliMuted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
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

String latencyText(int? latencyMs) {
  if (latencyMs == null) {
    return '未测';
  }
  return '${latencyMs}ms';
}

String storeUrl(AppController controller) {
  final baseUrl = controller.session?.baseUrl ?? 'https://sp.huhu.icu';
  return '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/#/store';
}

Future<void> copyStoreUrl(
    BuildContext context, AppController controller) async {
  await Clipboard.setData(ClipboardData(text: storeUrl(controller)));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('商店地址已复制')));
  }
}

Future<void> openStore(BuildContext context, AppController controller) async {
  final url = storeUrl(controller);
  var opened = false;

  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
      opened = true;
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
      opened = true;
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
      opened = true;
    }
  } catch (_) {
    opened = false;
  }

  if (!opened) {
    await Clipboard.setData(ClipboardData(text: url));
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(opened ? '正在打开面板商店' : '商店地址已复制，请在浏览器打开')),
    );
  }
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
