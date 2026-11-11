"""Build a low-memory CUDA-compatible BiRefNet model from the pinned MIT export.

The export uses native DeformConv (CPU-only in ONNX Runtime 1.24). Replace it
with equivalent GridSample + 1x1 Conv operations supported on CUDA. Evaluate at
512px and convert to FP16: the stock 1024px GatherND export exceeds available
VRAM on a busy 8GB desktop GPU. This script is run only in the Nix build.
"""
import sys
import numpy as np
import onnx
from onnx import helper as h, numpy_helper as nh
from onnxconverter_common import float16


def convert(source, target):
    model = onnx.load(source)
    for value in [*model.graph.input, *model.graph.output]:
        dims = value.type.tensor_type.shape.dim
        dims[2].dim_value = 512
        dims[3].dim_value = 512
    del model.graph.value_info[:]
    tensors = {t.name: nh.to_array(t) for t in model.graph.initializer}
    for node in model.graph.node:
        if node.op_type == "Identity" and node.input[0] in tensors:
            tensors[node.output[0]] = tensors[node.input[0]]
        elif node.op_type == "Constant":
            for attr in node.attribute:
                if attr.name == "value":
                    tensors[node.output[0]] = nh.to_array(attr.t)
    output_nodes = []
    for number, node in enumerate(model.graph.node):
        if node.op_type != "DeformConv":
            output_nodes.append(node)
            continue
        prefix = f"outline_deform_{number}_"
        attrs = {a.name: h.get_attribute_value(a) for a in node.attribute}
        if attrs.get("group", 1) != 1 or attrs.get("offset_group", 1) != 1:
            raise ValueError("Only ungrouped deformable convolution is supported")
        x, weight, offset, bias, mask = node.input
        weights = tensors[weight]
        co, ci, kh, kw = weights.shape
        k = kh * kw
        sy, sx = attrs.get("strides", [1, 1])
        dy, dx = attrs.get("dilations", [1, 1])
        py, px = attrs.get("pads", [0, 0, 0, 0])[:2]

        def const(name, value, dtype=np.int64):
            name = prefix + name
            model.graph.initializer.append(nh.from_array(np.asarray(value, dtype=dtype), name))
            return name

        def op(kind, name, *inputs, **attributes):
            name = prefix + name
            output_nodes.append(h.make_node(kind, list(inputs), [name], name=name, **attributes))
            return name

        zero = const("zero", 0)
        one = const("one", 1)
        axis1 = const("axis1", [1])
        axis3 = const("axis3", [3])
        shape_x = op("Shape", "shape_x", x)
        shape_o = op("Shape", "shape_o", offset)
        n = op("Gather", "n", shape_x, const("i0", [0]), axis=0)
        hi = op("Gather", "hi", shape_x, const("i2", [2]), axis=0)
        wi = op("Gather", "wi", shape_x, const("i3", [3]), axis=0)
        ho = op("Gather", "ho", shape_o, const("j2", [2]), axis=0)
        wo = op("Gather", "wo", shape_o, const("j3", [3]), axis=0)
        hos = op("Squeeze", "hos", ho, const("axis0", [0]))
        wos = op("Squeeze", "wos", wo, const("axis0b", [0]))
        ry = op("Cast", "ry", op("Range", "range_y", zero, hos, one), to=1)
        rx = op("Cast", "rx", op("Range", "range_x", zero, wos, one), to=1)
        yy = op("Reshape", "yy", ry, const("y_shape", [1, 1, -1, 1]))
        xx = op("Reshape", "xx", rx, const("x_shape", [1, 1, 1, -1]))
        os = op("Concat", "offset_shape", n, const("k2", [k, 2]), ho, wo, axis=0)
        offsets = op("Reshape", "offsets", offset, os)
        oy = op("Gather", "oy", offsets, zero, axis=2)
        ox = op("Gather", "ox", offsets, one, axis=2)
        ky = const("ky", (np.repeat(np.arange(kh), kw) * dy - py).reshape(1, k, 1, 1), np.float32)
        kx = const("kx", (np.tile(np.arange(kw), kh) * dx - px).reshape(1, k, 1, 1), np.float32)
        yy = op("Add", "base_y", op("Mul", "stride_y", yy, const("sy", sy, np.float32)), ky)
        xx = op("Add", "base_x", op("Mul", "stride_x", xx, const("sx", sx, np.float32)), kx)
        yy = op("Add", "sample_y", yy, oy)
        xx = op("Add", "sample_x", xx, ox)
        for name, value, extent in [("y", yy, hi), ("x", xx, wi)]:
            size = op("Cast", name + "_size", op("Sub", name + "_extent", extent, one), to=1)
            normalized = op("Sub", name + "_norm", op("Mul", name + "_twice",
                op("Div", name + "_fraction", value, size), const(name + "_two", 2, np.float32)),
                const(name + "_one", 1, np.float32))
            transposed = op("Transpose", name + "_transpose", normalized, perm=[0, 2, 3, 1])
            shape = op("Concat", name + "_grid_shape", n, ho, op("Mul", name + "_wk", wo, const(name + "_k", [k])), axis=0)
            flat = op("Reshape", name + "_flat", transposed, shape)
            if name == "y":
                gy = op("Unsqueeze", "gy", flat, axis3)
            else:
                gx = op("Unsqueeze", "gx", flat, axis3)
        grid = op("Concat", "grid", gx, gy, axis=3)
        samples = op("GridSample", "samples", x, grid, align_corners=1, mode="bilinear", padding_mode="zeros")
        shape = op("Concat", "sample_shape", n, const("ci", [ci]), ho, wo, const("kk", [k]), axis=0)
        samples = op("Reshape", "sample_5d", samples, shape)
        samples = op("Transpose", "sample_transpose", samples, perm=[0, 1, 4, 2, 3])
        samples = op("Mul", "masked", samples, op("Unsqueeze", "mask", mask, axis1))
        shape = op("Concat", "conv_shape", n, const("cik", [ci * k]), ho, wo, axis=0)
        samples = op("Reshape", "conv_input", samples, shape)
        flattened_weight = const("weight", weights.reshape(co, ci * k, 1, 1), np.float32)
        output_nodes.append(h.make_node("Conv", [samples, flattened_weight, bias], list(node.output),
                                       name=prefix + "conv", kernel_shape=[1, 1]))
    del model.graph.node[:]
    model.graph.node.extend(output_nodes)
    # ORT's CUDA GridSample kernel accepts FP32, not FP16; keep only these
    # nodes in FP32 so sampling does not silently get assigned to the CPU.
    model = float16.convert_float_to_float16(model, keep_io_types=True,
        op_block_list=[*float16.DEFAULT_OP_BLOCK_LIST, "GridSample"],
        # Keep pixel coordinates in FP32 too: rounding normalized coordinates
        # to FP16 can move sampling locations by a quarter pixel at 512px.
        node_block_list=[n.name for n in model.graph.node
                         if n.name.startswith("outline_deform_") and not n.name.endswith("_conv")])
    # This dynamic export contains explicit float Casts whose attributes are
    # not updated by onnxconverter-common alongside their value_info types.
    types = {v.name: v.type.tensor_type.elem_type for v in
             [*model.graph.value_info, *model.graph.input, *model.graph.output]}
    for node in model.graph.node:
        if node.op_type == "Cast" and node.output[0] in types:
            for attr in node.attribute:
                if attr.name == "to":
                    attr.i = types[node.output[0]]
    onnx.checker.check_model(model)
    onnx.save(model, target)


if __name__ == "__main__":
    convert(*sys.argv[1:])
