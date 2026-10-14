#!/usr/bin/env python3
"""RSS Reader 的 App 图标生成器（设计稿 + 各平台资源）。

只依赖 Pillow。设计规则来自 Apple 官方图标网格（macOS）：

    1024×1024 画布，圆角方 824×824（圆角半径 185.4）居中，四周留 100px
    给投影；圆角与投影都要画进图里 —— macOS 不会替应用裁圆角、加投影。
    实测本仓库原有的 Flutter 模板图标：不透明区 (101,101)-(923,923)、
    投影延伸到 (934,944)，与上面这套数字吻合。

两种母版：
  * `mode="macos"`：带留白 + 投影，给 macOS 的 AppIcon.appiconset
  * `mode="bleed"`：满幅方形、无圆角无投影，给 iOS / Web / Android legacy
    （这些平台由系统/浏览器自己裁圆角；Android adaptive 的安全区另算）

几何全部按 1024 坐标写，内部在 4096（4× 超采样）上绘制，最后缩到目标尺寸，
所以 1024 / 256 / 32 / 16 都是同一次绘制的缩放结果，比例不会漂。

用法：

    python3 tool/icon/generate_icons.py drafts    # 出设计稿 + 对照表
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------- 画布几何

CANVAS = 1024
SS = 4  # 超采样倍数
PLATE = 824  # 圆角方边长
INSET = (CANVAS - PLATE) // 2  # 100
RADIUS = 185.4  # Apple 网格的圆角半径
SHADOW_OFFSET = 8  # 下面三个数字是按 Flutter 模板图标的投影剖面拟合出来的
SHADOW_BLUR = 6
SHADOW_ALPHA = 0.30  # 模板图标投影最深约 77/255，这条曲线下是 72

ACCENT = "#F4600F"  # 主色橙
INK = "#232B3B"  # 墨色

# 标记比例：在小尺寸对照里逐组看过，这组（大 + 粗）在 32/64px 下最清楚。
# 一道弧的简化版在 16px 更锐，但会丢掉「RSS」的识别度，不采用。
# 标记的定稿比例：全部相对 ink（外接方框边长）。小尺寸（16/24/32/48/64/128/256）
# 逐组比出来的，改动前先跑 drafts 看一眼。
DEFAULT_MARK = dict(ink=470, stroke=0.190, gap=0.140, dot=0.145, nudge=(0, 4), cap="round")


def up(v: float) -> int:
    """1024 坐标 → 超采样坐标。"""
    return int(round(v * SS))


def rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def rgba(value: str, alpha: float) -> tuple[int, int, int, int]:
    return (*rgb(value), int(round(alpha * 255)))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# ---------------------------------------------------------------- 基础图形


def interp_rgb(stops: list[tuple[float, tuple[int, int, int]]], t: float) -> tuple[int, int, int]:
    if t <= stops[0][0]:
        return stops[0][1]
    if t >= stops[-1][0]:
        return stops[-1][1]
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if p0 <= t <= p1:
            return mix(c0, c1, (t - p0) / (p1 - p0))
    return stops[-1][1]


def interp_scalar(stops: list[tuple[float, float]], t: float) -> float:
    if t <= stops[0][0]:
        return stops[0][1]
    if t >= stops[-1][0]:
        return stops[-1][1]
    for (p0, v0), (p1, v1) in zip(stops, stops[1:]):
        if p0 <= t <= p1:
            return v0 + (v1 - v0) * (t - p0) / (p1 - p0)
    return stops[-1][1]


def vertical_gradient(
    size: int,
    stops: list[tuple[float, str]],
    alpha_stops: list[tuple[float, float]] | None = None,
) -> Image.Image:
    """竖直渐变（size×size）。stops 的 pos 是高度比例，0 = 顶部。"""
    rgb_stops = sorted((pos, rgb(c)) for pos, c in stops)
    a_stops = sorted(alpha_stops) if alpha_stops else [(0.0, 1.0), (1.0, 1.0)]
    col = Image.new("RGBA", (1, size))
    load = col.load()
    for y in range(size):
        t = y / max(1, size - 1)
        load[0, y] = (*interp_rgb(rgb_stops, t), int(round(interp_scalar(a_stops, t) * 255)))
    return col.resize((size, size), Image.Resampling.BILINEAR)


def plate_mask(mode: str) -> Image.Image:
    """圆角方遮罩（超采样尺寸）。bleed 母版是满幅方形。"""
    mask = Image.new("L", (CANVAS * SS, CANVAS * SS), 0)
    d = ImageDraw.Draw(mask)
    if mode == "bleed":
        d.rectangle([0, 0, mask.width - 1, mask.height - 1], fill=255)
        return mask
    pad = up(INSET)
    d.rounded_rectangle(
        [pad, pad, mask.width - 1 - pad, mask.height - 1 - pad], radius=up(RADIUS), fill=255
    )
    return mask


def radial_glow(center: tuple[float, float], radius: float, color: str, alpha: float) -> Image.Image:
    """柔和径向光晕（超采样尺寸）。"""
    n = 512
    blob = Image.new("L", (n, n), 0)
    ImageDraw.Draw(blob).ellipse([0, 0, n - 1, n - 1], fill=255)
    blob = blob.filter(ImageFilter.GaussianBlur(n * 0.16))
    side = up(radius * 2)
    glow = Image.new("RGBA", (side, side), rgba(color, alpha))
    glow.putalpha(blob.resize((side, side), Image.Resampling.BILINEAR).point(lambda v: int(v * alpha)))
    layer = Image.new("RGBA", (CANVAS * SS, CANVAS * SS), (0, 0, 0, 0))
    layer.alpha_composite(glow, (up(center[0] - radius), up(center[1] - radius)))
    return layer


# ---------------------------------------------------------------- 波浪标记


@dataclass
class Mark:
    """广播/波纹标记：圆点 + 两道 90° 圆弧，圆心重合在圆点上、朝右上开口。

    尺寸都相对 `ink`（标记外接方框边长 = 最外侧弧的外半径）取值，
    这样缩到 16px 时线宽/间距的比例稳定，不会「细线糊成一团」。
    """

    ink: float
    stroke: float = 0.175  # 线宽
    gap: float = 0.115  # 两弧之间的空隙
    dot: float = 0.16  # 圆点半径
    nudge: tuple[float, float] = (0.0, 0.0)  # 视觉微调（1024 坐标）
    cap: str = "round"  # 弧的端头：round = 与线宽齐平的圆头；butt = 平切

    @property
    def dot_r(self) -> float:
        return self.dot * self.ink

    @property
    def stroke_w(self) -> float:
        return self.stroke * self.ink

    def anchor(self) -> tuple[float, float]:
        """圆点（也是两弧圆心）位置：让整个标记的外接方框居中。

        外接方框 = 左下角圆点的左/下沿 + 右上角最外弧的外沿，两条边都由它定死。
        """
        r = self.dot_r
        c = CANVAS / 2
        ax = c - self.ink / 2 + r
        ay = c + self.ink / 2 - r
        return (ax + self.nudge[0], ay + self.nudge[1])

    def radii(self) -> tuple[float, float]:
        """两道弧的**外缘**半径（最外那道让外接方框正好等于 ink）。

        注意 Pillow 的 arc(width=) 是从外缘往内画的（实测：bbox 半径 90、宽 20
        → 落笔半径 70…90），所以这里给的就是 bbox 半径，线宽自己往里长。
        """
        r2 = self.ink - self.dot_r
        r1 = r2 - self.stroke_w - self.gap * self.ink
        return r1, r2

    def scaled(self, k: float) -> "Mark":
        """等比缩放（`dot` / `stroke` / `gap` 都是相对值，跟着 ink 走）。"""
        return Mark(
            ink=self.ink * k,
            stroke=self.stroke,
            gap=self.gap,
            dot=self.dot,
            nudge=(self.nudge[0] * k, self.nudge[1] * k),
            cap=self.cap,
        )

    def max_radius(self) -> float:
        """画布中心到墨迹最远点的距离（弧端圆帽与圆点各算一个候选）。

        Android adaptive / Web maskable 的「安全区」是一个圆，
        用得上这个数（与缩放系数成正比，所以能反解缩放）。
        """
        ax, ay = self.anchor()
        c = CANVAS / 2
        best = math.hypot(ax - c, ay - c) + self.dot_r
        r_out = self.radii()[1]  # 最外那道弧的外缘就是最远的墨迹
        for ex, ey in ((ax + r_out, ay), (ax, ay - r_out)):
            best = max(best, math.hypot(ex - c, ey - c))
        return best

    def mask(self) -> Image.Image:
        """标记的 L 遮罩（超采样尺寸）。"""
        mask = Image.new("L", (CANVAS * SS, CANVAS * SS), 0)
        d = ImageDraw.Draw(mask)
        ax, ay = self.anchor()
        w = up(self.stroke_w)
        for r in self.radii():
            d.arc(
                [up(ax - r), up(ay - r), up(ax + r), up(ay + r)],
                start=-90,
                end=0,
                fill=255,
                width=w,
            )
            # PIL 的 arc 没有 round cap：两端各补一个圆，圆心在**线中心**上
            # （放在外缘会鼓出一个球，就是「弧两头有黑点」那个毛病）
            if self.cap == "round":
                rc = r - self.stroke_w / 2
                cap = self.stroke_w / 2
                for ex, ey in ((ax, ay - rc), (ax + rc, ay)):
                    d.ellipse([up(ex - cap), up(ey - cap), up(ex + cap), up(ey + cap)], fill=255)
        r = self.dot_r
        d.ellipse([up(ax - r), up(ay - r), up(ax + r), up(ay + r)], fill=255)
        return mask


def paint(mask: Image.Image, fill: Image.Image | tuple[int, int, int, int]) -> Image.Image:
    """按遮罩给一层上色；fill 可以是纯色或一张全画布渐变图。"""
    layer = fill.copy() if isinstance(fill, Image.Image) else Image.new("RGBA", mask.size, fill)
    return Image.composite(layer, Image.new("RGBA", mask.size, (0, 0, 0, 0)), mask)


# ---------------------------------------------------------------- 设计方向


@dataclass
class Variant:
    key: str
    name: str
    desc: str
    bg: list[tuple[float, str]]
    mark_fill: str | list[tuple[float, str]] = "#FFFFFF"  # 纯色 或 自顶向下的渐变
    mark: Mark = field(default_factory=lambda: Mark(**DEFAULT_MARK))
    gloss: list[tuple[float, float]] = field(default_factory=lambda: [(0.0, 0.0), (1.0, 0.0)])
    glow: tuple[str, float, float] | None = None  # (color, alpha, radius)
    border: float = 0.0  # 内描边 alpha（黑），浅底图标靠它定形
    dot_fill: str | None = None  # 圆点单独上色（如「墨弧 + 橙点」）

    _cache: dict[str, Image.Image] = field(default_factory=dict, repr=False, compare=False)

    def master(self, mode: str = "macos", mark_scale: float | None = None) -> Image.Image:
        """1024 母版。

        `mode="macos"` 是设计稿那套（圆角方 824 + 留白 + 投影）；`bleed` 是
        满幅方形母版（iOS / Web / Android），此时整张图按 1024/824 放大，
        等于把圆角方那块裁下来 —— 跨平台看到的「标记占可见区多大」一致。
        `mark_scale` 是标记的**绝对**缩放系数（相对设计稿那套几何），None = 各模式的默认；
        给 Android adaptive / Web maskable 的安全区用，值由 `fit_scale()` 算。
        """
        if mark_scale is None:
            mark_scale = 1.0 if mode == "macos" else CANVAS / PLATE
        key = f"{mode}:{mark_scale:.4f}"
        if key in self._cache:
            return self._cache[key]
        k = mark_scale
        mark = self.mark.scaled(k)
        s = CANVAS * SS
        mask = plate_mask(mode)

        out = Image.new("RGBA", (s, s), (0, 0, 0, 0))

        # 1. 投影（只有 macOS 母版要；Apple 网格里那 100px 留白就是给它）
        if mode == "macos":
            blurred = mask.filter(ImageFilter.GaussianBlur(up(SHADOW_BLUR)))
            shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
            shadow.paste(
                Image.new("RGBA", (s, s), (0, 0, 0, int(SHADOW_ALPHA * 255))),
                (0, up(SHADOW_OFFSET)),
                blurred,
            )
            out.alpha_composite(shadow)

        # 2. 底板：竖直渐变
        plate = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        plate.paste(vertical_gradient(s, self.bg), (0, 0), mask)

        # 3. 顶部高光：很淡，只给底板一点体积感
        if any(a > 0 for _, a in self.gloss):
            top = INSET / CANVAS if mode == "macos" else 0.0
            bottom = (INSET + PLATE) / CANVAS if mode == "macos" else 1.0
            gloss = vertical_gradient(
                s,
                [(0.0, "#FFFFFF"), (1.0, "#FFFFFF")],
                alpha_stops=[(top, self.gloss[0][1]), (bottom, self.gloss[-1][1])],
            )
            plate.alpha_composite(paint(mask, gloss))

        # 4. 标记背后的光晕
        if self.glow:
            color, alpha, radius = self.glow
            glow = radial_glow(mark.anchor(), radius * k, color, alpha)
            plate.alpha_composite(paint(mask, glow))

        # 5. 标记（弧 + 点）
        fill: Image.Image | tuple[int, int, int, int]
        if isinstance(self.mark_fill, list):
            fill = vertical_gradient(s, self.mark_fill)
        else:
            fill = rgba(self.mark_fill, 1.0)
        plate.alpha_composite(paint(mark.mask(), fill))

        # 6. 圆点单独上色
        if self.dot_fill:
            dot_mask = Image.new("L", (s, s), 0)
            ImageDraw.Draw(dot_mask).ellipse(_dot_box(mark), fill=255)
            plate.alpha_composite(paint(dot_mask, rgba(self.dot_fill, 1.0)))

        # 7. 内描边（只有 macOS 母版要：bleed 由系统裁圆角，边缘本来就贴着画布）
        if self.border > 0 and mode == "macos":
            ring = Image.new("L", (s, s), 0)
            ImageDraw.Draw(ring).rounded_rectangle(
                [up(INSET), up(INSET), s - 1 - up(INSET), s - 1 - up(INSET)],
                radius=up(RADIUS),
                outline=255,
                width=up(3),
            )
            ring = ring.filter(ImageFilter.GaussianBlur(up(1)))
            plate.alpha_composite(paint(ring, rgba("#000000", self.border)))

        out.alpha_composite(plate)
        self._cache[key] = out
        return out

    def render(self, size: int = CANVAS, mode: str = "macos", mark_scale: float | None = None) -> Image.Image:
        """按目标尺寸直接缩（一次重采样，16/32px 比「1024 缩下来」更挺）。"""
        return self.master(mode, mark_scale).resize((size, size), Image.Resampling.LANCZOS)

    def fit_scale(self, ratio: float) -> float:
        """标记的绝对缩放系数，使「画布中心到墨迹最远点」= ratio × 画布边长。

        Android adaptive 的安全圈是 108dp 里的 66dp 直径（半径 30.6%），
        Web maskable 是 80% 直径（半径 40%）。标记是斜向的（外接框对角线最远），
        直接按外接框缩放会在圆角遮罩下把角切掉，所以按半径反解。
        """
        return ratio * CANVAS / self.mark.max_radius()

    def mark_only(self, size: int, mark_scale: float = 1.0, mono: str | None = None) -> Image.Image:
        """透明底、只有标记的一张图（Android adaptive 的 foreground / monochrome）。

        mark_scale 同样是绝对系数：Android 用 `fit_scale(0.3056) * CANVAS/PLATE` 那一档。
        """
        s = CANVAS * SS
        layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        mark = self.mark.scaled(mark_scale)
        if mono:
            fill: Image.Image | tuple[int, int, int, int] = rgba(mono, 1.0)
        elif isinstance(self.mark_fill, list):
            fill = vertical_gradient(s, self.mark_fill)
        else:
            fill = rgba(self.mark_fill, 1.0)
        layer.alpha_composite(paint(mark.mask(), fill))
        if mono is None and self.dot_fill:
            dot_mask = Image.new("L", (s, s), 0)
            ImageDraw.Draw(dot_mask).ellipse(_dot_box(mark), fill=255)
            layer.alpha_composite(paint(dot_mask, rgba(self.dot_fill, 1.0)))
        return layer.resize((size, size), Image.Resampling.LANCZOS)


def _dot_box(mark: Mark) -> list[int]:
    ax, ay = mark.anchor()
    r = mark.dot_r
    return [up(ax - r), up(ay - r), up(ax + r), up(ay + r)]


def variants() -> dict[str, Variant]:
    return {
        "a": Variant(
            key="a",
            name="A · 经典橙",
            desc="橙底白波纹 —— 最像 RSS，小尺寸最稳",
            bg=[(0.0, "#FFA544"), (0.55, "#F87A1C"), (1.0, "#EC4A0B")],
            gloss=[(0.0, 0.22), (0.30, 0.0), (1.0, 0.0)],
        ),
        "b": Variant(
            key="b",
            name="B · 墨蓝夜",
            desc="深墨蓝底 + 橙渐变波纹 —— 深色 Dock 下更稳",
            bg=[(0.0, "#2B3650"), (1.0, "#0F1523")],
            mark_fill=[(0.0, "#FFC069"), (1.0, "#F4620F")],
            gloss=[(0.0, 0.10), (0.35, 0.0), (1.0, 0.0)],
            glow=("#5A6E9C", 0.45, 520),
        ),
        "c": Variant(
            key="c",
            name="C · 纸墨",
            desc="米白纸底 + 墨弧橙点 —— 阅读器的气质",
            bg=[(0.0, "#FFFDF8"), (1.0, "#EFE5D6")],
            mark_fill=INK,
            dot_fill=ACCENT,
            border=0.10,
        ),
        "d": Variant(
            key="d",
            name="D · 白瓷",
            desc="白底 + 橙渐变波纹 —— 最接近 macOS 原生",
            bg=[(0.0, "#FFFFFF"), (1.0, "#EDEFF3")],
            mark_fill=[(0.0, "#FFA83F"), (1.0, "#EE4C0C")],
            border=0.12,
        ),
    }


# ---------------------------------------------------------------- 对照表


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in (
        "/System/Library/Fonts/Hiragino Sans GB.ttc",  # 有中文
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def contact_sheet(items: list[Variant], out: Path) -> None:
    """一个方向一行：大图 + 浅底/深底的真实尺寸 + 放大镜。"""
    sizes = [16, 32, 64, 128]
    zoom = {16: 10, 32: 5, 64: 3, 128: 2}
    big, pad, label_h = 256, 22, 38
    light, dark = "#E9E9EE", "#2B2B30"
    strip_h = 168
    strip_w = 16 + sum(s + 16 for s in sizes)
    zoom_w = sum(s * zoom[s] + 16 for s in sizes)
    row_w = pad + big + pad + strip_w + pad + zoom_w + pad
    row_h = label_h + strip_h * 2 + 22
    sheet = Image.new("RGB", (row_w, row_h * len(items) + pad), "#FFFFFF")
    d = ImageDraw.Draw(sheet)
    f_title, f_small = font(23), font(14)

    for i, v in enumerate(items):
        master = v.render()
        y0 = pad + i * row_h
        d.text((pad, y0), v.name, font=f_title, fill="#111111")
        d.text((pad + d.textlength(v.name, font=f_title) + 14, y0 + 6), v.desc, font=f_small, fill="#777777")
        y = y0 + label_h

        # 大图（放在浅色格子上的观感）
        cell = Image.new("RGBA", (big, big), "#FFFFFF")
        sheet.paste(Image.alpha_composite(cell, master.resize((big, big), Image.Resampling.LANCZOS)).convert("RGB"), (pad, y))

        # 浅底 / 深底：16 / 32 / 64 / 128 的真实像素
        x = pad + big + pad
        for strip, bg_color in enumerate((light, dark)):
            sy = y + strip * strip_h
            sheet.paste(Image.new("RGB", (strip_w, strip_h), bg_color), (x, sy))
            sx = x + 16
            for s in sizes:
                small = v.render(s)
                tile = Image.new("RGBA", (s, s), (0, 0, 0, 0))
                tile.alpha_composite(small)
                sheet.paste(tile.convert("RGB"), (sx, sy + (strip_h - s) // 2))
                sx += s + 16
            d.text((x + 4, sy + strip_h - 18), "浅色底" if strip == 0 else "深色底", font=f_small, fill="#999999")
        d.text((x, y + strip_h * 2 + 2), "16 · 32 · 64 · 128 实际像素", font=f_small, fill="#999999")

        # 放大镜：16/32 到底长什么样
        zx = x + strip_w + pad
        for s in sizes:
            side = s * zoom[s]
            z = v.render(s).resize((side, side), Image.Resampling.NEAREST)
            tile = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            tile.alpha_composite(z)
            sheet.paste(tile.convert("RGB"), (zx, y + 4))
            d.text((zx + 2, y + side + 10), f"{s}px ×{zoom[s]}", font=f_small, fill="#999999")
            zx += side + 16

    sheet.save(out)
    print(f"  → {out}")


# ---------------------------------------------------------------- 各平台资源

MACOS_DIR = REPO / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
# 文件名与尺寸按 Contents.json 核过（10 条记录映射到 7 个文件）
MACOS_FILES = {
    16: "app_icon_16.png",
    32: "app_icon_32.png",
    64: "app_icon_64.png",
    128: "app_icon_128.png",
    256: "app_icon_256.png",
    512: "app_icon_512.png",
    1024: "app_icon_1024.png",
}

IOS_DIR = REPO / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
# 文件名 → 像素边长（= Contents.json 里的 size × scale，19 条记录映射到 15 个文件）
IOS_FILES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_RES = REPO / "android/app/src/main/res"
ANDROID_DENSITIES = [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0), ("xxhdpi", 3.0), ("xxxhdpi", 4.0)]
ANDROID_ADAPTIVE_SAFE_RATIO = 0.3056  # 108dp 里安全圈直径 66dp

WEB_DIR = REPO / "web"
WEB_MASKABLE_SAFE_RATIO = 0.38  # 标准是 80% 直径，留 2% 余量
WINDOWS_ICO = REPO / "windows/runner/resources/app_icon.ico"
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]

WEB_HEAD_START = "  <!-- icon:start 由 tool/icon/generate_icons.py 生成，勿手改 -->"
WEB_HEAD_END = "  <!-- icon:end -->"


def _save_png(img: Image.Image, path: Path, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = img.convert("RGB") if opaque else img
    img.save(path, "PNG", optimize=True)


def _describe(path: Path, expect: int, want_alpha: bool | None = None) -> str:
    """回读文件核对（「生成器跑成功但没动文件」是常见坑，所以写完必回读）。"""
    with Image.open(path) as im:
        size = im.size
        alpha_span = None
        if im.mode == "RGBA":
            lo, hi = im.getchannel("A").getextrema()
            alpha_span = (lo, hi)
    ok = size == (expect, expect)
    note = f"{size[0]}×{size[1]}" if ok else f"❗期望 {expect}×{expect}，实得 {size[0]}×{size[1]}"
    if alpha_span is not None:
        note += "，有透明" if alpha_span[0] < 255 else "，全不透明"
    else:
        note += "，无 alpha 通道"
    if want_alpha is True and alpha_span and alpha_span[0] == 255:
        note += " ❗本应有透明"
    if want_alpha is False and alpha_span and alpha_span[0] < 255:
        note += " ❗本应不透明"
    return note


def _web_head_block(theme: str) -> str:
    return "\n".join(
        [
            WEB_HEAD_START,
            '  <link rel="icon" href="favicon.png">',
            '  <link rel="apple-touch-icon" href="icons/Icon-192.png">',
            '  <link rel="manifest" href="manifest.json">',
            f'  <meta name="theme-color" content="{theme}">',
            WEB_HEAD_END,
        ]
    )


def _patch_index_html(path: Path, block: str, dry: bool = False) -> str:
    """把 head 里的图标引用块换成最新版（靠 start/end 注释定位，重复跑不变样）。"""
    import re

    html = path.read_text(encoding="utf-8")
    if WEB_HEAD_START in html:
        new = re.sub(
            re.escape(WEB_HEAD_START) + r".*?" + re.escape(WEB_HEAD_END), block, html, flags=re.S
        )
        action = "已更新" if new != html else "未变"
    else:
        anchor = '  <base href="$FLUTTER_BASE_HREF">'
        if anchor not in html:
            raise SystemExit(f"{path} 里找不到 {anchor}，手动看一眼再改")
        new = html.replace(anchor, anchor + "\n" + block)
        action = "已插入"
    if new != html and not dry:
        path.write_text(new, encoding="utf-8")
    return action


@dataclass
class _Written:
    """一条导出记录：最后那张核对表就靠它（写完必须回读）。"""

    platform: str
    path: Path
    note: str
    png: tuple[int, bool | None] | None = None  # (边长, 该不该带透明)


def cmd_export(variant_key: str, only: list[str] | None, dry: bool) -> None:
    v = variants()[variant_key]
    want = set(only) if only else {"macos", "ios", "android", "web", "windows"}
    theme = v.bg[0][1]  # 浅色那端（纸底），给浏览器 / PWA 的主题色
    out: list[_Written] = []

    def emit(
        platform: str,
        path: Path,
        img: Image.Image,
        note: str,
        size: int,
        opaque: bool = False,
        alpha: bool | None = None,
    ) -> None:
        if not dry:
            _save_png(img, path, opaque=opaque)
        out.append(_Written(platform, path, note, (size, alpha)))

    def note_only(platform: str, path: Path, note: str) -> None:
        out.append(_Written(platform, path, note))

    # macOS：保留 100px 留白 + 投影；Contents.json 不动（改了会动 Xcode 的工程引用）
    if "macos" in want:
        for size, name in MACOS_FILES.items():
            emit("macOS", MACOS_DIR / name, v.render(size, "macos"), f"{size}px", size, alpha=True)

    # iOS：满幅方图（圆角由系统裁），不能带 alpha
    if "ios" in want:
        for name, size in IOS_FILES.items():
            emit("iOS", IOS_DIR / name, v.render(size, "bleed"), f"{size}px", size, opaque=True, alpha=False)

    # Android：legacy 方图 + adaptive 的 foreground / monochrome / 背景渐变
    if "android" in want:
        for density, scale in ANDROID_DENSITIES:
            legacy = int(48 * scale)
            emit(
                "Android",
                ANDROID_RES / f"mipmap-{density}/ic_launcher.png",
                v.render(legacy, "bleed"),
                f"legacy {legacy}px",
                legacy,
                alpha=False,  # 满幅方图，本就全不透明
            )
            fg = int(108 * scale)
            for suffix, mono, note in (
                ("foreground", None, "adaptive foreground"),
                ("monochrome", "#000000", "adaptive monochrome"),
            ):
                emit(
                    "Android",
                    ANDROID_RES / f"mipmap-{density}/ic_launcher_{suffix}.png",
                    v.mark_only(fg, v.fit_scale(ANDROID_ADAPTIVE_SAFE_RATIO), mono=mono),
                    f"{note} {fg}px",
                    fg,
                    alpha=True,
                )

        adaptive = ANDROID_RES / "mipmap-anydpi-v26/ic_launcher.xml"
        background = ANDROID_RES / "drawable/ic_launcher_background.xml"
        if not dry:
            adaptive.parent.mkdir(parents=True, exist_ok=True)
            background.parent.mkdir(parents=True, exist_ok=True)
            adaptive.write_text(_adaptive_xml(), encoding="utf-8")
            background.write_text(_background_xml(v), encoding="utf-8")
        note_only("Android", adaptive, "adaptive-icon：background + foreground + monochrome")
        note_only("Android", background, "背景渐变（与母版同一组色）")

    # Web：favicon + PWA 图标 + manifest，并在 index.html 里挂上引用
    if "web" in want:
        for name, size, maskable in (
            ("favicon.png", 32, False),
            ("icons/Icon-192.png", 192, False),
            ("icons/Icon-512.png", 512, False),
            ("icons/Icon-maskable-192.png", 192, True),
            ("icons/Icon-maskable-512.png", 512, True),
        ):
            emit(
                "Web",
                WEB_DIR / name,
                v.render(size, "bleed", v.fit_scale(WEB_MASKABLE_SAFE_RATIO) if maskable else None),
                f"{size}px" + ("（maskable，标记缩到安全圈内）" if maskable else ""),
                size,
                alpha=False,  # 满幅方图，本就全不透明
            )
        manifest = WEB_DIR / "manifest.json"
        if not dry:
            manifest.write_text(
                json.dumps(_manifest(theme), indent=4, ensure_ascii=False) + "\n", encoding="utf-8"
            )
        note_only("Web", manifest, "PWA manifest（图标清单与上面几行一一对应）")
        action = _patch_index_html(WEB_DIR / "index.html", _web_head_block(theme), dry)
        note_only("Web", WEB_DIR / "index.html", f"head 里的图标引用{action}")

    # Windows：多尺寸 .ico（本机不构建 Windows，文件写了但没实机验证过）
    if "windows" in want:
        if not dry:
            WINDOWS_ICO.parent.mkdir(parents=True, exist_ok=True)
            v.render(1024, "macos").save(WINDOWS_ICO, sizes=[(s, s) for s in ICO_SIZES])
        with Image.open(WINDOWS_ICO) as im:
            got = sorted(s[0] for s in im.ico.sizes())
        flag = "" if got == ICO_SIZES else " ❗尺寸不全"
        note_only("Windows", WINDOWS_ICO, "、".join(str(s) for s in got) + f"px{flag}")

    print(f"方向 {v.name} · {v.desc}（{'演练，不写文件' if dry else '已写入'}）")
    for w in out:
        extra = _describe(w.path, *w.png) if w.png and not dry else ""
        print(f"  {w.platform:8s} {str(w.path.relative_to(REPO)):58s} {w.note:34s} {extra}")


def _adaptive_xml() -> str:
    return """<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tool/icon/generate_icons.py 生成，勿手改 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <!-- monochrome 是 API 33+ 的主题化图标，低版本会忽略这一行 -->
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""


def _background_xml(v: Variant) -> str:
    """adaptive 的背景层：母版的竖直渐变，用 shape drawable 画。angle=270 是自上而下。"""
    top, bottom = v.bg[0][1], v.bg[-1][1]
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tool/icon/generate_icons.py 生成，勿手改 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="270"
        android:startColor="{top}"
        android:endColor="{bottom}" />
</shape>
"""


def _manifest(theme: str) -> dict:
    return {
        "name": "RSS Reader",
        "short_name": "RSS Reader",
        "start_url": ".",
        "display": "standalone",
        "background_color": theme,
        "theme_color": theme,
        "description": "本地存储的 RSS / Atom 阅读器",
        "orientation": "any",
        "prefer_related_applications": False,
        "icons": [
            {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
            {
                "src": "icons/Icon-maskable-192.png",
                "sizes": "192x192",
                "type": "image/png",
                "purpose": "maskable",
            },
            {
                "src": "icons/Icon-maskable-512.png",
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "maskable",
            },
        ],
    }


# ---------------------------------------------------------------- CLI


def cmd_drafts(outdir: Path, only: list[str] | None) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    vs = variants()
    if only:
        vs = {k: v for k, v in vs.items() if k in only}
    for v in vs.values():
        for size in (1024, 256, 128, 64, 32, 16):
            v.render(size).save(outdir / f"{v.key}_{size}.png")
        print(f"  {outdir}/{v.key}_*.png  ({v.name})")
    contact_sheet(list(vs.values()), outdir / "sheet.png")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("drafts", help="生成设计草稿与对照表")
    p.add_argument("--outdir", type=Path, default=REPO / "build/icon_drafts")
    p.add_argument("--only", nargs="*", help="只做某几个方向，如 a c")
    p.set_defaults(func=lambda a: cmd_drafts(a.outdir, a.only))
    e = sub.add_parser("export", help="把定稿的方向写进各平台资源目录")
    e.add_argument("variant", choices=sorted(variants()), help="选定的方向")
    e.add_argument("--only", nargs="*", help="只导出某几个平台：macos ios android web windows")
    e.add_argument("--dry-run", action="store_true", help="只打印计划与回读结果，不写文件")
    e.set_defaults(func=lambda a: cmd_export(a.variant, a.only, a.dry_run))
    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
