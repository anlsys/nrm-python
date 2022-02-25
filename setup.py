"""Argo Node Resource Manager
"""

from setuptools import setup, find_packages

setup(
    name='nrm',
    version='0.7.0',
    description="Argo Node Resource Manager",
    author='Swann Perarnau',
    author_email='swann@anl.gov',
    url='http://argo-osr.org',
    license='BSD3',

    classifiers=[
        'Development Status :: 3 - Alpha',
        'License :: OSI Approved :: BSD License',
        'Programming Language :: Python :: 3.6',
    ],

    packages=find_packages(),
    install_requires=['msgpack', 'pyyaml', "warlock", "pyzmq", "tornado", "jsonschema"],
    package_data={'nrm': ['schemas/*.json', 'schemas/*.yml']},
    scripts=['bin/nrmd']
)
