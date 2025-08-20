import struct
import numpy as np
from PIL import Image
import os

def read_idx_images(filename):
    with open(filename, 'rb') as f:
        magic, num_images, rows, cols = struct.unpack('>IIII', f.read(16))
        if magic != 2051:
            raise ValueError(f"Invalid magic number {magic} in image file")
        data = np.frombuffer(f.read(), dtype=np.uint8)
        return data.reshape(num_images, rows, cols)

def read_idx_labels(filename):
    with open(filename, 'rb') as f:
        magic, num_labels = struct.unpack('>II', f.read(8))
        if magic != 2049:
            raise ValueError(f"Invalid magic number {magic} in label file")
        return np.frombuffer(f.read(), dtype=np.uint8)

def save_images(images, labels, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for i, (img, label) in enumerate(zip(images, labels)):
        img_path = os.path.join(output_dir, f"{label}_{i}.png")
        Image.fromarray(img, mode='L').save(img_path)
    print(f"Saved {len(images)} images to {output_dir}")

if __name__ == "__main__":
    # Change to your MNIST file paths
    train_images_path = "./data/train-images-idx3-ubyte"
    train_labels_path = "./data/train-labels-idx1-ubyte"

    test_images_path = "./data/t10k-images.idx3-ubyte"
    test_labels_path = "./data/t10k-labels.idx1-ubyte"

    # Read datasets
    train_images = read_idx_images(train_images_path)
    train_labels = read_idx_labels(train_labels_path)
    test_images = read_idx_images(test_images_path)
    test_labels = read_idx_labels(test_labels_path)

    # Save as PNGs
    save_images(train_images, train_labels, "../data/mnist_train")
    save_images(test_images, test_labels, "../data/mnist_test")
