from setuptools import setup, find_packages

setup(
    name='borneopy',
    version='0.1.0',
    packages=find_packages(),
    install_requires=[
    ],
    author='Yunnan BinaryStars Technologies Co., Ltd.',
    author_email='oldrev@gmail.com',
    description='A open-source Python client library for devices under the Borneo-IoT Project',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://github.com/oldrev/borneo',
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: GPLv3 License',
        'Operating System :: OS Independent',
    ],
    python_requires='>=3.6',
)