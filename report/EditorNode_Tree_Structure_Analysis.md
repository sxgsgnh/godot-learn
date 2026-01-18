# EditorNode 整体 Node 树结构分析

## 概览

EditorNode 是 Godot 编辑器的主控制节点，包含 **9 个直接子节点**（不含 GUI 对话框），形成一个分层的 Node 树。该树可分为两个主要部分：

1. **系统服务层**：直接添加到 EditorNode 的系统组件（计时器、资源管理器等）
2. **UI 显示层**：通过 gui_base（Panel）容器管理的可视化界面组件

---

## 第一层：EditorNode 的直接子节点

```
EditorNode
├── EditorPropertyNameProcessor (line 8220)
├── EditorFileSystem (line 8436)
├── EditorExport (line 8447)
├── EditorResourcePreview (line 8472)
├── ProgressDialog (line 8474)
├── Panel (gui_base) ✓ UI 根容器
├── Timer (editor_layout_save_delay_timer, 0.5s)
├── Timer (scan_changes_timer, 0.5s)
└── AudioStreamPreviewGenerator (line 9098)
```

### 直接子节点说明

| 节点名称 | 类型 | 行号 | 用途 | 生命周期 |
|---------|------|------|------|---------|
| epnp | EditorPropertyNameProcessor | 8220 | 属性名称处理和转换 | 常驻 |
| efs | EditorFileSystem | 8436 | 文件系统扫描与资源监控 | 常驻 |
| editor_export | EditorExport | 8447 | 项目导出配置管理 | 常驻 |
| resource_preview | EditorResourcePreview | 8472 | 资源预览生成（缩略图等） | 常驻 |
| progress_dialog | ProgressDialog | 8474 | 长操作进度提示对话框 | 常驻 |
| **gui_base** | **Panel** | **8478** | **主 UI 容器根节点** | **常驻** |
| editor_layout_save_delay_timer | Timer | 8589 | 延迟保存编辑器布局（防止频繁保存） | 常驻 |
| scan_changes_timer | Timer | 8598 | 定期扫描文件系统变化 | 常驻 |
| audio_preview_gen | AudioStreamPreviewGenerator | 9098 | 音频资源预览生成 | 常驻 |

---

## 第二层：gui_base 容器结构

### Android 平台特有结构（#ifdef ANDROID_ENABLED）

```
gui_base (Panel)
├── base_vbox (VBoxContainer)
│   ├── title_bar (EditorTitleBar) ← 顶部标题栏
│   └── main_hbox (HBoxContainer)
│       └── main_vbox (VBoxContainer)
│           └── main_hsplit (DockSplitContainer) → 跳转到第三层
```

### 其他平台结构

```
gui_base (Panel)
├── main_vbox (VBoxContainer)
│   ├── title_bar (EditorTitleBar) ← 顶部标题栏
│   └── main_hsplit (DockSplitContainer) → 跳转到第三层
```

**注**：两种结构最终都指向 main_hsplit，是编辑器布局的核心容器。

---

## 第三层：主分割容器 (main_hsplit) 水平布局

main_hsplit 是 DockSplitContainer（支持拖拽调整尺寸的分割器），水平排列 5 个主要区域：

```
main_hsplit (DockSplitContainer, 水平)
├─[0] left_l_vsplit (DockSplitContainer, 垂直)
├─[1] left_r_vsplit (DockSplitContainer, 垂直)
├─[2] center_vb (VBoxContainer)
├─[3] right_l_vsplit (DockSplitContainer, 垂直)
└─[4] right_r_vsplit (DockSplitContainer, 垂直)
```

### 分割布局配置

从 `set_split_offsets()` 可看出（line 8962）：
- **left_l_vsplit** 宽度: `280 * EDSCALE`（固定宽度，左侧场景树区域）
- **left_r_vsplit** 宽度: `280 * EDSCALE`（固定宽度）
- **center_vb** 宽度: 自动填充剩余空间
- **right_l_vsplit** 宽度: `280 * EDSCALE`（固定宽度）
- **right_r_vsplit** 宽度: `280 * EDSCALE`（固定宽度，右侧检查器区域）

---

## 第四层：Dock 系统 - 左侧分割器

### left_l_vsplit（左上-左下分割）

```
left_l_vsplit (DockSplitContainer, 垂直)
├── DockSlotLeftUL (TabContainer)
│   └── SceneTreeDock (场景树导出器) + ImportDock (导入工具)
└── DockSlotLeftBL (TabContainer)
    └── FileSystemDock (文件系统浏览器)
```

**用途**：编辑器左侧面板，展示项目结构和场景层级

---

### left_r_vsplit（左上-左下分割，右侧）

```
left_r_vsplit (DockSplitContainer, 垂直)
├── DockSlotLeftUR (TabContainer)
│   └── [用户自定义面板]
└── DockSlotLeftBR (TabContainer)
    └── HistoryDock (操作历史)
```

**用途**：扩展左侧功能区

---

## 第五层：中心区域 (center_vb) - 编辑视口

```
center_vb (VBoxContainer)
└── center_split (DockSplitContainer, 垂直)
    ├── top_split (VSplitContainer) ← 上方编辑区域
    │   ├── srt (VBoxContainer)
    │   │   ├── scene_tabs (EditorSceneTabs) ← 场景标签页
    │   │   └── editor_main_screen (EditorMainScreen) ← 2D/3D/脚本编辑器主显示区
    │   └── [可选底部分割区域]
    │
    └── bottom_panel (EditorBottomPanel) ← 底部输出面板
        └── EditorLog (输出日志)
```

### 关键组件说明

- **scene_tabs**: 编辑器场景标签页，可切换多个打开的场景
- **editor_main_screen**: 主编辑区域容器，根据当前编辑模式显示不同编辑器
  - 2D 编辑器
  - 3D 编辑器
  - 脚本编辑器
  - 游戏视图
  - 资源库视图
- **bottom_panel**: 底部输出面板，显示调试信息、错误日志等

---

## 第六层：右侧检查器区域

### right_l_vsplit（右上-右下分割）

```
right_l_vsplit (DockSplitContainer, 垂直)
├── DockSlotRightUL (TabContainer)
│   └── InspectorDock (属性检查器)
└── DockSlotRightBL (TabContainer)
    └── SignalsDock (信号面板) + GroupsDock (分组面板)
```

**用途**：节点属性编辑和信号管理

---

### right_r_vsplit（右上-右下分割，右侧）

```
right_r_vsplit (DockSplitContainer, 垂直)
├── DockSlotRightUR (TabContainer)
│   └── [用户自定义面板]
└── DockSlotRightBR (TabContainer)
    └── [用户自定义面板]
```

**用途**：额外扩展区域

---

## 第七层：顶部标题栏 (EditorTitleBar) 结构

```
title_bar (EditorTitleBar)
├── left_menu_spacer (Control, 可选)
├── file_menu (PopupMenu)
├── project_menu (PopupMenu)
├── debug_menu (PopupMenu)
├── settings_menu (PopupMenu)
├── help_menu (PopupMenu)
├── left_spacer (HBoxContainer)
│   └── project_title (Label)
├── main_editor_button_hb (HBoxContainer)
│   └── [2D/3D/脚本/资源库按钮等]
├── right_spacer (Control)
├── project_run_bar (EditorRunBar)
│   └── [运行/停止按钮]
├── right_menu_hb (HBoxContainer)
│   └── renderer (OptionButton) ← 渲染器选择
└── right_menu_spacer (Control, 可选)
```

**用途**：编辑器主菜单栏和工具栏

---

## 第八层：对话框和浮窗（都是 gui_base 的子节点）

gui_base 除了包含主 UI 容器外，还作为所有对话框的父容器（通过 `gui_base->add_child()`）：

### 主要对话框（32+ 个）

```
gui_base (Panel)
├── [主 UI 层级 → main_vbox 等]
│
├─ 项目导出对话框
│   ├── project_export (ProjectExportDialog)
│   └── file_android_build_source (EditorFileDialog)
│
├─ 设置对话框
│   ├── editor_settings_dialog (EditorSettingsDialog)
│   ├── project_settings_editor (ProjectSettingsEditor)
│   └── layout_dialog (EditorLayoutsDialog)
│
├─ 导入设置对话框
│   ├── scene_import_settings (SceneImportSettingsDialog)
│   ├── audio_stream_import_settings (AudioStreamImportSettingsDialog)
│   └── fontdata_import_settings (DynamicFontImportSettingsDialog)
│
├─ 模板和特性管理
│   ├── export_template_manager (ExportTemplateManager)
│   ├── feature_profile_manager (EditorFeatureProfileManager)
│   ├── build_profile_manager (EditorBuildProfileManager)
│   ├── file_templates (EditorFileDialog)
│   ├── gradle_build_manage_templates (ConfirmationDialog)
│   ├── install_android_build_template (ConfirmationDialog)
│   └── remove_android_build_template (ConfirmationDialog)
│
├─ 文件对话框
│   ├── file (EditorFileDialog)
│   ├── file_export_lib (EditorFileDialog)
│   └── file_pack_zip (EditorFileDialog)
│
├─ 确认对话框
│   ├── confirmation (ConfirmationDialog)
│   ├── save_confirmation (ConfirmationDialog)
│   └── disk_changed (ConfirmationDialog)
│
├─ 快速打开和搜索
│   ├── quick_open_dialog (EditorQuickOpenDialog)
│   ├── quick_open_color_palette (EditorQuickOpenDialog)
│   └── command_palette (EditorCommandPalette)
│
├─ 其他功能
│   ├── dependency_error (DependencyErrorDialog)
│   ├── orphan_resources (OrphanResourcesDialog)
│   ├── native_shader_source_visualizer (EditorNativeShaderSourceVisualizer)
│   ├── about (EditorAbout)
│   ├── fbx_importer_manager (FBXImporterManager, 非 Android/Web 平台)
│   ├── pick_main_scene (EditorQuickOpenDialog)
│   ├── open_project_settings (EditorQuickOpenDialog)
│   └── open_imported (EditorQuickOpenDialog)
│
└── warning (AcceptDialog) [set_unparent_when_invisible = true，隐式管理]
```

**注**：
- 大多数对话框设置了 `set_unparent_when_invisible(true)`，在隐藏时自动脱离树
- 部分对话框（特别是 Android 特定的）只在特定平台编译

---

## 完整树形图

```
EditorNode (Node)
│
├─ [系统服务子节点]
│   ├─ EditorPropertyNameProcessor
│   ├─ EditorFileSystem
│   ├─ EditorExport
│   ├─ EditorResourcePreview
│   ├─ ProgressDialog
│   ├─ Timer (editor_layout_save_delay_timer)
│   ├─ Timer (scan_changes_timer)
│   └─ AudioStreamPreviewGenerator
│
└─ Panel (gui_base) ★ 主 UI 容器
   │
   ├─ [Platform: Android]
   │   └─ VBoxContainer (base_vbox)
   │       ├─ EditorTitleBar (title_bar)
   │       └─ HBoxContainer (main_hbox)
   │           └─ VBoxContainer (main_vbox)
   │               └─ DockSplitContainer (main_hsplit)
   │
   ├─ [Platform: Others]
   │   └─ VBoxContainer (main_vbox)
   │       ├─ EditorTitleBar (title_bar)
   │       └─ DockSplitContainer (main_hsplit)
   │
   └─ DockSplitContainer (main_hsplit, 水平) ★ 布局核心
      │
      ├─ DockSplitContainer (left_l_vsplit, 垂直)
      │   ├─ TabContainer (DockSlotLeftUL)
      │   │   ├─ SceneTreeDock
      │   │   └─ ImportDock
      │   └─ TabContainer (DockSlotLeftBL)
      │       └─ FileSystemDock
      │
      ├─ DockSplitContainer (left_r_vsplit, 垂直)
      │   ├─ TabContainer (DockSlotLeftUR)
      │   └─ TabContainer (DockSlotLeftBR)
      │       └─ HistoryDock
      │
      ├─ VBoxContainer (center_vb)
      │   └─ DockSplitContainer (center_split, 垂直)
      │       ├─ VSplitContainer (top_split)
      │       │   ├─ VBoxContainer (srt)
      │       │   │   ├─ EditorSceneTabs (scene_tabs)
      │       │   │   └─ EditorMainScreen (editor_main_screen) ★
      │       │   └─ [底部可选区域]
      │       └─ EditorBottomPanel (bottom_panel)
      │           └─ EditorLog (log)
      │
      ├─ DockSplitContainer (right_l_vsplit, 垂直)
      │   ├─ TabContainer (DockSlotRightUL)
      │   │   └─ InspectorDock
      │   └─ TabContainer (DockSlotRightBL)
      │       ├─ SignalsDock
      │       └─ GroupsDock
      │
      └─ DockSplitContainer (right_r_vsplit, 垂直)
          ├─ TabContainer (DockSlotRightUR)
          └─ TabContainer (DockSlotRightBR)
      
      [以及 32+ 个对话框作为 gui_base 的直接子节点]
```

---

## 关键设计特点

### 1. **分离式架构**
- **系统服务层**（直接添加到 EditorNode）：后台处理，不参与视觉布局
- **UI 显示层**（gui_base 容器）：前台交互，完整的可视化界面

### 2. **Dock 系统**
- 使用 TabContainer 实现可切换的面板
- DockSplitContainer 支持拖拽调整面板大小
- EditorDockManager 集中管理所有 Dock 插槽

### 3. **对话框管理**
- 所有对话框都是 gui_base 的子节点
- 大多数支持 `set_unparent_when_invisible(true)` 自动清理
- 浮动状态下仍保持在场景树中

### 4. **尺寸管理**
- 默认 Dock 宽度固定为 280 * EDSCALE
- center_vb 设置 SIZE_EXPAND_FILL，自动占用剩余空间
- 支持保存/恢复布局配置

### 5. **平台适配**
- Android 平台增加 base_vbox 和 main_hbox 包装层
- 条件编译控制平台特定组件（如 FBXImporterManager）

---

## 性能影响分析

### 较重的常驻组件
1. **EditorFileSystem** - 持续监控文件系统变化，定期扫描
2. **EditorResourcePreview** - 后台生成资源预览
3. **AudioStreamPreviewGenerator** - 音频预览生成

### 可清理的非关键组件
1. 各类对话框（支持延迟加载）
2. 特定平台的组件（Android 特定功能）
3. 不常用的 Dock 面板

---

## 适用于 rm-editor 分支的优化方向

基于此结构分析，rm-editor 分支可以考虑：

1. **移除系统服务**：可选禁用 EditorResourcePreview、AudioStreamPreviewGenerator
2. **简化 UI**：移除右侧检查器（InspectorDock）等非必需面板
3. **精简对话框**：移除导出、项目设置等功能对话框
4. **禁用文件监控**：关闭 EditorFileSystem 的实时扫描
5. **最小化编辑器**：只保留 editor_main_screen 中的必要编辑器模式

