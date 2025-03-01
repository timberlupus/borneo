from setuptools import setup, find_packages

setup(
    name='borneoiot',
    version='0.1.0',
    packages=find_packages(),
    install_requires=[
    ],
    author='Yunnan BinaryStars Technologies Co., Ltd.',
    author_email='oldrev@gmail.com',
    description='A open-source Python client library for devices under the Borneo-IoT Project',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://www.borneoiot.com',
    license='GPL3.0+',
    classifiers=[
        'Programming Language :: Python :: 3',
        'Operating System :: OS Independent',
    ],
    python_requires='>=3.6',
    package_data={
        'mypackage': ['examples/*.py'],
    },
)